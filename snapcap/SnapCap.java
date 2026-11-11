// SnapCap: capture media audio from all apps on Android 13+ and write raw PCM
// (48000 Hz, 16-bit, stereo) to stdout, for a Snapcast pipe source.
//
// Apps whose uid is given as an argument are NOT captured and keep playing on
// the device (e.g. the Snapcast client on the host). Captured apps are muted on
// the device, so the host can play in sync through its own Snapcast client.
//
// Run as the shell user (needs MODIFY_AUDIO_ROUTING):
//   CLASSPATH=/data/local/tmp/snapcap.jar app_process / SnapCap <excludeUid>... > fifo
//
// The AudioPolicy and fake context approach is adapted from scrcpy
// (https://github.com/Genymobile/scrcpy, Apache-2.0).

import android.app.Application;
import android.app.Instrumentation;
import android.content.AttributionSource;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.pm.ApplicationInfo;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioRecord;
import android.os.Looper;
import android.os.Process;

import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;

public final class SnapCap {

    static final String PACKAGE_NAME = "com.android.shell";
    static final int SAMPLE_RATE = 48000;

    private static Class<?> activityThreadClass;
    private static Object activityThread;

    static final class FakeContext extends ContextWrapper {
        FakeContext(Context base) {
            super(base);
        }

        @Override
        public String getPackageName() {
            return PACKAGE_NAME;
        }

        @Override
        public String getOpPackageName() {
            return PACKAGE_NAME;
        }

        @Override
        public AttributionSource getAttributionSource() {
            return new AttributionSource.Builder(Process.SHELL_UID).setPackageName(PACKAGE_NAME).build();
        }

        @Override
        public Context getApplicationContext() {
            return this;
        }
    }

    private static FakeContext setUpContext() throws Exception {
        activityThreadClass = Class.forName("android.app.ActivityThread");
        Constructor<?> ctor = activityThreadClass.getDeclaredConstructor();
        ctor.setAccessible(true);
        activityThread = ctor.newInstance();
        setField(activityThreadClass, null, "sCurrentActivityThread", activityThread);
        setField(activityThreadClass, activityThread, "mSystemThread", true);

        // Android 12+: configuration controller
        Class<?> ccClass = Class.forName("android.app.ConfigurationController");
        Class<?> atiClass = Class.forName("android.app.ActivityThreadInternal");
        Constructor<?> ccCtor = ccClass.getDeclaredConstructor(atiClass);
        ccCtor.setAccessible(true);
        setField(activityThreadClass, activityThread, "mConfigurationController", ccCtor.newInstance(activityThread));

        // App info, so the process identifies as com.android.shell
        Class<?> bindDataClass = Class.forName("android.app.ActivityThread$AppBindData");
        Constructor<?> bindCtor = bindDataClass.getDeclaredConstructor();
        bindCtor.setAccessible(true);
        Object bindData = bindCtor.newInstance();
        ApplicationInfo info = new ApplicationInfo();
        info.packageName = PACKAGE_NAME;
        setField(bindDataClass, bindData, "appInfo", info);
        setField(activityThreadClass, activityThread, "mBoundApplication", bindData);

        Method getSystemContext = activityThreadClass.getDeclaredMethod("getSystemContext");
        FakeContext context = new FakeContext((Context) getSystemContext.invoke(activityThread));

        Application app = Instrumentation.newApplication(Application.class, context);
        setField(activityThreadClass, activityThread, "mInitialApplication", app);
        return context;
    }

    private static void setField(Class<?> cls, Object obj, String name, Object value) throws Exception {
        Field f = cls.getDeclaredField(name);
        f.setAccessible(true);
        f.set(obj, value);
    }

    private static AudioRecord createRecord(Context context, int[] excludeUids) throws Exception {
        Class<?> ruleClass = Class.forName("android.media.audiopolicy.AudioMixingRule");
        Class<?> ruleBuilderClass = Class.forName("android.media.audiopolicy.AudioMixingRule$Builder");
        Object ruleBuilder = ruleBuilderClass.getConstructor().newInstance();

        int mixRolePlayers = ruleClass.getField("MIX_ROLE_PLAYERS").getInt(null);
        ruleBuilderClass.getMethod("setTargetMixRole", int.class).invoke(ruleBuilder, mixRolePlayers);

        int matchUsage = ruleClass.getField("RULE_MATCH_ATTRIBUTE_USAGE").getInt(null);
        Method addMixRule = ruleBuilderClass.getMethod("addMixRule", int.class, Object.class);
        for (int usage : new int[]{AudioAttributes.USAGE_MEDIA, AudioAttributes.USAGE_GAME, AudioAttributes.USAGE_UNKNOWN}) {
            addMixRule.invoke(ruleBuilder, matchUsage, new AudioAttributes.Builder().setUsage(usage).build());
        }

        int matchUid = ruleClass.getField("RULE_MATCH_UID").getInt(null);
        Method excludeMixRule = ruleBuilderClass.getMethod("excludeMixRule", int.class, Object.class);
        for (int uid : excludeUids) {
            excludeMixRule.invoke(ruleBuilder, matchUid, uid);
        }
        Object rule = ruleBuilderClass.getMethod("build").invoke(ruleBuilder);

        Class<?> mixClass = Class.forName("android.media.audiopolicy.AudioMix");
        Class<?> mixBuilderClass = Class.forName("android.media.audiopolicy.AudioMix$Builder");
        Object mixBuilder = mixBuilderClass.getConstructor(ruleClass).newInstance(rule);
        AudioFormat format = new AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
                .build();
        mixBuilderClass.getMethod("setFormat", AudioFormat.class).invoke(mixBuilder, format);
        // LOOP_BACK only: captured apps are not rendered on the device
        int loopBack = mixClass.getField("ROUTE_FLAG_LOOP_BACK").getInt(null);
        mixBuilderClass.getMethod("setRouteFlags", int.class).invoke(mixBuilder, loopBack);
        Object mix = mixBuilderClass.getMethod("build").invoke(mixBuilder);

        Class<?> policyClass = Class.forName("android.media.audiopolicy.AudioPolicy");
        Class<?> policyBuilderClass = Class.forName("android.media.audiopolicy.AudioPolicy$Builder");
        Object policyBuilder = policyBuilderClass.getConstructor(Context.class).newInstance(context);
        policyBuilderClass.getMethod("addMix", mixClass).invoke(policyBuilder, mix);
        Object policy = policyBuilderClass.getMethod("build").invoke(policyBuilder);

        Method register = AudioManager.class.getDeclaredMethod("registerAudioPolicyStatic", policyClass);
        register.setAccessible(true);
        int result = (int) register.invoke(null, policy);
        if (result != 0) {
            throw new RuntimeException("registerAudioPolicy() returned " + result);
        }
        return (AudioRecord) policyClass.getMethod("createAudioRecordSink", mixClass).invoke(policy, mix);
    }

    public static void main(String[] args) throws Exception {
        int[] excludeUids = new int[args.length];
        for (int i = 0; i < args.length; i++) {
            excludeUids[i] = Integer.parseInt(args[i]);
        }

        Looper.prepareMainLooper();
        FakeContext context = setUpContext();
        AudioRecord record = createRecord(context, excludeUids);
        record.startRecording();
        System.err.println("snapcap: capturing, excluded uids: " + args.length);

        FileOutputStream out = new FileOutputStream(FileDescriptor.out);
        byte[] buf = new byte[SAMPLE_RATE / 50 * 4]; // 20 ms
        try {
            while (true) {
                int n = record.read(buf, 0, buf.length);
                if (n < 0) {
                    throw new IOException("AudioRecord.read() returned " + n);
                }
                out.write(buf, 0, n);
            }
        } finally {
            record.release();
        }
    }
}
