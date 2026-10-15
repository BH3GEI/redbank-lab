package com.yao.synpad;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.os.*;
import android.view.*;
import android.view.Gravity;
import android.widget.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

public class MainActivity extends Activity {
    static final String MOUNT = "192.168.4.1";
    static final int PORT = 11880;
    static final double CTS_DEG = 16777216.0 / 360.0;

    DatagramSocket sock;
    volatile String speed = "200000";
    TextView posView, msgView;
    EditText raIn, decIn;
    Handler ui = new Handler(Looper.getMainLooper());
    volatile boolean alive = true;

    synchronized String cmd(String s) {
        try {
            if (sock == null) sock = new DatagramSocket();
            byte[] out = (s + "\r").getBytes(StandardCharsets.US_ASCII);
            sock.send(new DatagramPacket(out, out.length, InetAddress.getByName(MOUNT), PORT));
            byte[] in = new byte[64];
            DatagramPacket p = new DatagramPacket(in, in.length);
            sock.setSoTimeout(1200);
            sock.receive(p);
            return new String(p.getData(), 0, p.getLength(), StandardCharsets.US_ASCII).trim();
        } catch (Exception e) { return "!"; }
    }

    long rawPos(int axis) {
        String r = cmd(":j" + axis);
        if (!r.startsWith("=") || r.length() < 7) return 0;
        try {
            int v = Integer.parseInt(r.substring(1), 16);
            if (v > 0x7FFFFF) v -= 0x1000000;
            return v;
        } catch (Exception e) { return 0; }
    }

    static double wrap180(double v) { while (v > 180) v -= 360; while (v <= -180) v += 360; return v; }

    void startAxis(int axis, int dir) { // dir 0=CW,1=CCW (counts +/- unknown per axis, user learns)
        new Thread(() -> {
            cmd(":K" + axis);
            cmd(":G" + axis + "3" + dir);
            cmd(":I" + axis + speed);
            cmd(":J" + axis);
        }).start();
    }
    void stopAxis(int axis) { new Thread(() -> cmd(":K" + axis)).start(); }

    void goTargets(final double raDeg, final double decDeg) {
        new Thread(() -> {
            final long ra0 = rawPos(1), dec0 = rawPos(2);
            double d1 = raDeg, d2 = decDeg;
            // input = absolute degrees on encoder circle; take shortest path for RA
            double cur1 = wrap180(ra0 / CTS_DEG), cur2 = wrap180(dec0 / CTS_DEG);
            double delta1 = wrap180(d1 - cur1), delta2 = d2 - cur2;
            // clamp DEC against saved limits (degrees absolute)
            double[] lim = limits();
            double tgt2 = cur2 + delta2;
            if (lim[0] != lim[1]) {
                if (tgt2 < lim[0]) { uiToast("DEC低于下限，拒绝"); return; }
                if (tgt2 > lim[1]) { uiToast("DEC高于上限，拒绝"); return; }
            }
            slewBy(1, delta1);
            slewBy(2, delta2);
            // poll until both done
            long t1 = Math.round(delta1 * CTS_DEG), t2 = Math.round(delta2 * CTS_DEG);
            for (int i = 0; i < 600 && alive; i++) {
                if (Math.abs(wrap180((rawPos(1) - ra0) / CTS_DEG) - delta1) < 0.3
                 && Math.abs(wrap180((rawPos(2) - dec0) / CTS_DEG) - delta2) < 0.3) break;
                try { Thread.sleep(120); } catch (Exception e) {}
            }
            cmd(":K1"); cmd(":K2");
            uiToast("到位");
        }).start();
    }

    void slewBy(int axis, double deltaDeg) {
        if (Math.abs(deltaDeg) < 0.01) return;
        int dir = deltaDeg > 0 ? 0 : 1; // CW for positive; swapped if user's mount differs
        cmd(":K" + axis);
        cmd(":G" + axis + "3" + dir);
        cmd(":I" + axis + speed);
        cmd(":J" + axis);
    }

    void setSpeed(String v) { speed = v; }

    double[] limits() {
        android.content.SharedPreferences sp = getPreferences(Context.MODE_PRIVATE);
        return new double[]{ sp.getFloat("decLo", 0), sp.getFloat("decHi", 0) };
    }

    void uiToast(String m) { runOnUiThread(() -> Toast.makeText(this, m, Toast.LENGTH_SHORT).show()); }

    Button mkBtn(String label, int size, int bg) {
        Button b = new Button(this);
        b.setText(label); b.setTextSize(size); b.setTextColor(Color.WHITE);
        b.setBackgroundColor(bg);
        return b;
    }

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(24, 40, 24, 24);
        root.setBackgroundColor(Color.rgb(17,17,17));

        posView = new TextView(this);
        posView.setTextColor(Color.rgb(150,255,150)); posView.setTextSize(15);
        root.addView(posView);

        msgView = new TextView(this);
        msgView.setTextColor(Color.rgb(255,100,100)); msgView.setTextSize(14);
        root.addView(msgView);

        // arrow grid
        GridView none = null;
        LinearLayout grid = new LinearLayout(this);
        grid.setOrientation(LinearLayout.VERTICAL);
        grid.setGravity(Gravity.CENTER);
        int BG = Color.rgb(38,38,38), BGD = Color.rgb(70,70,70);
        View.OnTouchListener hold = (v, ev) -> {
            int axis = (Integer) v.getTag(R.id.tag_axis);
            int dir = (Integer) v.getTag(R.id.tag_dir);
            switch (ev.getActionMasked()) {
                case MotionEvent.ACTION_DOWN: v.setBackgroundColor(BGD); startAxis(axis, dir); return true;
                case MotionEvent.ACTION_UP: case MotionEvent.ACTION_CANCEL:
                    v.setBackgroundColor(BG); stopAxis(axis); return true;
            }
            return false;
        };
        String[][] defs = {{"", "▲", ""}, {"◀","·","▶"}, {"", "▼", ""}};
        int[][] ax = {{0,2,0},{1,0,1},{0,2,0}};
        int[][] dr = {{0,0,0},{1,0,0},{0,0,1}};
        for (int r = 0; r < 3; r++) {
            LinearLayout row = new LinearLayout(this);
            row.setGravity(Gravity.CENTER);
            for (int c = 0; c < 3; c++) {
                Button bt = mkBtn(defs[r][c], 34, BG);
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(200, 200);
                lp.setMargins(8, 8, 8, 8);
                bt.setLayoutParams(lp);
                if (!defs[r][c].equals("·") && !defs[r][c].equals("")) {
                    bt.setTag(R.id.tag_axis, ax[r][c]);
                    bt.setTag(R.id.tag_dir, dr[r][c]);
                    bt.setOnTouchListener(hold);
                }
                if (defs[r][c].equals("")) bt.setVisibility(View.INVISIBLE);
                row.addView(bt);
            }
            grid.addView(row);
        }
        root.addView(grid);

        Button stop = mkBtn("■ 停", 22, Color.rgb(170,17,17));
        stop.setOnClickListener(v -> { stopAxis(1); stopAxis(2); });
        root.addView(stop);

        // speed row
        LinearLayout spd = new LinearLayout(this);
        String[] names = {"慢", "中", "快"};
        String[] vals = {"600000", "200000", "60000"};
        for (int i = 0; i < 3; i++) {
            final String v = vals[i];
            final String nm = names[i];
            Button bt = mkBtn(names[i], 15, BG);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
            lp.setMargins(8, 12, 8, 0);
            bt.setLayoutParams(lp);
            bt.setOnClickListener(x -> { setSpeed(v); uiToast("速度:" + nm); });
            spd.addView(bt);
        }
        root.addView(spd);

        // manual input
        LinearLayout in = new LinearLayout(this);
        raIn = new EditText(this); decIn = new EditText(this);
        raIn.setHint("RA°"); decIn.setHint("DEC°");
        raIn.setInputType(android.text.InputType.TYPE_CLASS_NUMBER | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL | android.text.InputType.TYPE_NUMBER_FLAG_SIGNED);
        decIn.setInputType(raIn.getInputType());
        LinearLayout.LayoutParams ep = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
        ep.setMargins(8, 16, 8, 0);
        raIn.setLayoutParams(ep); decIn.setLayoutParams(ep);
        in.addView(raIn); in.addView(decIn);
        Button go = mkBtn("转到", 15, Color.rgb(40,90,40));
        go.setLayoutParams(new LinearLayout.LayoutParams(220, LinearLayout.LayoutParams.WRAP_CONTENT));
        LinearLayout.LayoutParams gp = (LinearLayout.LayoutParams) go.getLayoutParams();
        gp.setMargins(8,16,0,0);
        go.setLayoutParams(gp);
        go.setOnClickListener(v -> {
            try {
                double ra = Double.parseDouble(raIn.getText().toString());
                double dec = Double.parseDouble(decIn.getText().toString());
                goTargets(ra, dec);
            } catch (Exception e) { uiToast("格式: 度数, 可带负号"); }
        });
        in.addView(go);
        root.addView(in);

        // fill current + limits
        LinearLayout util = new LinearLayout(this);
        Button cur = mkBtn("填入当前位置", 13, BG);
        cur.setOnClickListener(v -> {
            raIn.setText(String.format("%.2f", wrap180(rawPos(1) / CTS_DEG)));
            decIn.setText(String.format("%.2f", wrap180(rawPos(2) / CTS_DEG)));
        });
        Button setLo = mkBtn("DEC下限", 13, BG);
        Button setHi = mkBtn("DEC上限", 13, BG);
        setLo.setOnClickListener(v -> {
            double[] l = limits();
            float x = (float) wrap180(rawPos(2) / CTS_DEG);
            getPreferences(Context.MODE_PRIVATE).edit().putFloat("decLo", x).putFloat("decHi", (float) l[1]).apply();
            uiToast("下限=" + x);
        });
        setHi.setOnClickListener(v -> {
            double[] l = limits();
            float x = (float) wrap180(rawPos(2) / CTS_DEG);
            getPreferences(Context.MODE_PRIVATE).edit().putFloat("decLo", (float) l[0]).putFloat("decHi", x).apply();
            uiToast("上限=" + x);
        });
        for (Button bt : new Button[]{cur, setLo, setHi}) {
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
            lp.setMargins(8, 12, 8, 0);
            bt.setLayoutParams(lp);
            util.addView(bt);
        }
        root.addView(util);

        setContentView(root);

        Thread t = new Thread(() -> {
            while (alive) {
                final long p1 = rawPos(1), p2 = rawPos(2);
                runOnUiThread(() -> posView.setText(String.format("RA %.1f°   DEC %.1f°", p1 / CTS_DEG, p2 / CTS_DEG)));
                try { Thread.sleep(800); } catch (Exception e) { return; }
            }
        });
        t.start();
    }

    @Override protected void onDestroy() { alive = false; super.onDestroy(); }
}
