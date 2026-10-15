// ============================================================
// 第三红岸 · v0.9 外壳前半专用基体（由v0.8 mechanical_core复制修改）。
// 只用于导出 shell_front；外壳后半、两块底板沿用v0.8 STL，一字节不改。
// v0.9改动：屏槽加宽、前半插入件统一留0.5mm、顶板舌头减薄缩短；卡扣见 shell_front_v09.scad。
// 外壳前后各一件，底板前后各一件；新增接缝只有直条搭接面。
// 使用用户切片配置的尺寸 302.4 × 161.98 × 260 mm。
// 当前交付由 pyramid_body_v08.scad 和 v08/prepare_prints.py 导出。
// 外壳顶面朝下、底板平放，STL只含模型实体；本共用文件的旧展示入口不用于交付。
// 壳套在底板上,左右两面底边各 2 颗 M3 从外面拧进角块,整机一体。mini 直接放底板上。
// 螺丝:M3×12 ×4(壳→底板)、M4×8 ×4(屏 VESA,薄头)、M8×40 螺栓+螺母 ×4(脚)、3/8"×3/4" ×1(顶接 AZ-GTi)
// 屏竖着放(100 宽 × 167 高),接口边朝下,插头藏在屏下方壳壁后面。
// 单位 mm。
// part: preview | exploded | shell_front | shell_back | base_front | base_back | *_print
// ============================================================
part = "none";

/* ---------- 外形 ---------- */
base   = 210;   // 底边(方)
top    = 120;   // 顶边(方)
H      = 205;   // 总高
wall   = 2.4;   // 壁厚
tilt   = atan(((base-top)/2)/H);   // ≈12.4°
roof_t = 10;    // 顶板厚(已并入外壳)

/* ---------- 顶:接 AZ-GTi ---------- */
bolt_d   = 9.9;    // 3/8" 螺杆通孔
head_af  = 14.3;   // 3/8 六角头对边
head_h   = 5;      // 头槽深
cable_d  = 20;     // 走线孔(相机 USB)
cable_xy = 40;     // 走线孔在顶面后右角,避开台子 Ø72 底盘
az_base_d = 72;

/* ---------- 屏:7" 167×100×12 竖放,VESA75,接口边在下 ---------- */
sw = 104.6; sh = 167; sd = 12;   // v0.9：实测v0.8屏槽(100.8)宽度差3–4mm，按104.6设计；高度不变
scr_clear_w = 0.5;               // v0.9：屏槽左右每边0.5（高度方向仍0.4，实测正好）
vesa = 75;
screen_z   = 108;  // 屏中心离地
pad_t      = 3;    // 屏槽底板厚
plug_clear = 20;   // 屏下边插头避让(腔体往下开口,实际到底板为止 27mm)
m4_thru = 4.4;

/* ---------- Mac mini M4 ---------- */
mini    = [127, 127, 50];
mini_dy = -6;      // mini 前后位置:前面留 5 给屏幕螺丝头,后面留 34 给插头

/* ---------- 底板 ---------- */
base_w    = 206;   // 底板边长(比壳小 4,壳边稍微悬出,不露边)
base_t    = 4;
blk       = 26;    // 角块边长
blk_h     = 12;
blk_c     = 86;    // 角块中心离中(脚距 172)
lf_nut_af = 13.0; lf_nut_h = 6.5; lf_hole = 8.6;
m3_pilot  = 2.5;  m3_thru = 3.4;
m3_z      = 6;     // 水平连接孔，壳平面连接耳与底板角块同轴
m3_off    = 10;    // M3避开M8槽，最薄处约1.75mm；树脂固化后用M3丝锥攻牙

$fn = 72;

// 接缝避开屏、中央螺栓孔和侧面通风槽。
split_y = 21;
joint_gap = 0.25;       // 胶层/装配间隙，实际树脂收缩须由切片人员校准
side_lap_start = 16.4;  // 侧面通风槽之间的实墙，槽边分别在16与26
side_lap_end = 25.6;
side_lap_t = 2.4;
roof_lap_end = 27;      // 走线孔最近边y=30，不切到孔（v0.8后半的槽到27.25为止）
// v0.9：前半插入件对v0.8后半统一留0.5mm（v0.8为0.25，树脂件装不进）
front_clear = 0.5;
tongue_end = roof_lap_end + joint_gap - front_clear;   // 26.75：舌头端部距槽底0.5
tongue_z0  = H-roof_t-joint_gap+front_clear;          // 195.25：后半压条顶面194.75之上0.5
tongue_z1  = H-roof_t+roof_t/2-front_clear;           // 199.5 ：后半顶盖底面200之下0.5
base_lap = 12;

// ---- 坐标:前脸在 -y,+x 是观众右手;on_face(k, zc) 把子对象放到第 k 面离地 zc 处的外表面 ----
module on_face(k, zc){
  yc = -base/2 + zc*tan(tilt);
  rotate([0,0,k*90]) translate([0, yc, zc]) rotate([90-tilt, 0, 0]) children();
}
module frustum(b, t, h){ linear_extrude(height=h, scale=t/b) square(b, center=true); }
function half_out(z) = base/2 - z*tan(tilt);
function half_in(z)  = half_out(z) - wall/cos(tilt);
module shell_outer(){ frustum(base, top, H); }
module shell_inner(){ translate([0,0,-1]) frustum(2*half_in(-1), 2*half_in(H-roof_t), H-roof_t+1); }

// 屏槽内侧加厚:一圈 8 宽边框 + 3 厚槽底板,上端长进顶板;板上开三个减重窗,避开 VESA 四孔
module screen_pad(){
  on_face(0, screen_z) difference(){
    translate([-(sw/2)-8, -(sh/2)-8, -(sd+pad_t)]) cube([sw+16, sh+40, sd+pad_t-wall+0.01]);
    translate([-30, -30, -(sd+pad_t)-1]) cube([60, 60, sd+pad_t+2]);
    for (y=[-1,1]) translate([-38, y*62-14, -(sd+pad_t)-1]) cube([76, 28, sd+pad_t+2]);
  }
}
module screen_cut(){
  on_face(0, screen_z){
    translate([-sw/2-scr_clear_w, -sh/2-0.4, -sd]) cube([sw+2*scr_clear_w, sh+0.8, sd+6]);                                   // 屏口袋
    translate([-sw/2-scr_clear_w, -sh/2-plug_clear, -(sd+pad_t)]) cube([sw+2*scr_clear_w, plug_clear+0.5, sd+pad_t-wall]);  // 屏下插头腔,藏在壁后
    for (x=[-vesa/2, vesa/2], y=[-vesa/2, vesa/2]) translate([x, y, -sd-pad_t-1]) cylinder(d=m4_thru, h=pad_t+2);  // VESA M4
  }
}
module vents(){   // 左右面下部进风,背面上部出风
  for (k=[1,3]) on_face(k, 40)  for (i=[-2:2]) translate([i*14-2, -18, -wall-1]) cube([4, 36, wall+2]);
  on_face(2, H-45)              for (i=[-3:3]) translate([i*14-2, -14, -wall-1]) cube([4, 28, wall+2]);
}
module cord_slot(){   // 电源线出口:背面底部,带开口槽
  on_face(2, 12) translate([30,0,0]) { translate([0,0,-wall-1]) cylinder(d=14, h=wall+2); translate([-7,-30,-wall-1]) cube([14, 30, wall+2]); }
}
module roof_holes(){
  translate([0,0,H-roof_t-1]) cylinder(d=bolt_d, h=roof_t+2);
  translate([0,0,H-roof_t-0.01]) cylinder(d=(head_af+0.4)/cos(30), h=head_h, $fn=6);
  translate([cable_xy, cable_xy, H-roof_t-1]) cylinder(d=cable_d, h=roof_t+2);
}
module shell_mount_pads(){
  // 四个8×12mm平头承面：外侧x=±105，内侧x=±99.25。
  // 原底板角块外侧x=±99，留0.25装配隙，M3×12实际进入底块6mm。
  for (x=[-1,1], y=[-1,1])
    translate([x<0 ? -105 : 99.25, y*(blk_c+m3_off)-4, 0])
      cube([5.75,8,12]);
}
module shell_screws(){
  // 孔刀必须完全穿透连接耳；不能沿用v06只适用于薄斜壁的短孔刀。
  for (x=[-1,1], y=[-1,1])
    translate([x*102.125, y*(blk_c+m3_off), m3_z])
      rotate([0,90,0]) cylinder(d=m3_thru,h=10,center=true);
}
module shell(){
  difference(){
    union(){ difference(){ shell_outer(); shell_inner(); } intersection(){ screen_pad(); shell_outer(); } shell_mount_pads(); }
    screen_cut(); vents(); cord_slot(); roof_holes(); shell_screws();
  }
}
module shell_print(){ translate([0,0,H]) rotate([180,0,0]) shell(); }   // 顶面贴床

// ---- 底板 ----
module base_plate(){
  difference(){
    union(){
      translate([0,0,-base_t]) linear_extrude(base_t) square(base_w, center=true);
      for (x=[-1,1], y=[-1,1]) translate([x*blk_c - blk/2, y*blk_c - blk/2, 0]) cube([blk, blk, blk_h]);                 // 四角方块
      for (x=[-1,1], y=[-1,1]) translate([x*(mini[0]/2+4.5) - 4, mini_dy + y*45 - 4, 0]) cube([8, 8, 6]);                 // mini 定位:左右各两个
      for (x=[-1,1], y=[-1,1]) translate([x*40 - 4, mini_dy + y*(mini[1]/2+4.5) - 4, 0]) cube([8, 8, 6]);                 // 前后各两个
    }
    for (x=[-1,1], y=[-1,1]) translate([x*blk_c, y*blk_c, 0]) {
      translate([0,0,-base_t-1]) cylinder(d=lf_hole, h=base_t+blk_h+2);                                                   // M8 通孔
      translate([0,0,blk_h-lf_nut_h-0.5]) cylinder(d=(lf_nut_af+0.4)/cos(30), h=lf_nut_h+1, $fn=6);                      // M8 螺母槽,从上放
      translate([x*(blk/2+1), y*m3_off, m3_z]) rotate([0,90,0]) cylinder(d=m3_pilot, h=2*13, center=true);               // M3 底孔,从侧面进
    }
    translate([-40, mini_dy+45, -base_t-1]) cylinder(d=30, h=base_t+2);   // ★ mini 电源键手指孔(键在 mini 底面后左,位置待实测)
  }
}

// ---- 四块实际打印件 ----
module y_region(y0, y1) {
  translate([-300,y0,-50]) cube([600,y1-y0,350]);
}

// 随斜壁走的实心直条，只在侧壁中段；不增加任何圆环/独立连接件。
module side_lap_strip(y0,y1,clearance) {
  intersection() {
    y_region(y0,y1);
    difference() {
      frustum(2*(half_in(0)-clearance),
              2*(half_in(H-roof_t)-clearance), H-roof_t);
      translate([0,0,-0.1])
        frustum(2*(half_in(-0.1)-clearance-side_lap_t),
                2*(half_in(H-roof_t+0.1)-clearance-side_lap_t), H-roof_t+0.2);
    }
  }
}

module shell_front() {
  union() {
    intersection() { shell(); y_region(-300,split_y); }
    // 前端长进原壁0.5mm；后端距后壳内壁0.25mm供涂胶。
    side_lap_strip(side_lap_start,split_y,-0.5);
    side_lap_strip(split_y,side_lap_end,front_clear);
    // 顶板下半厚搭接，顶板中央承重孔完整留在前壳。
    intersection() {
      shell();
      translate([-300,split_y-0.1,tongue_z0])
        cube([600,tongue_end-split_y+0.1,tongue_z1-tongue_z0]);
    }
  }
}
module shell_back() {
  difference() {
    intersection() { shell(); y_region(split_y+joint_gap,300); }
    // 顶板上半留给后壳，与前壳下半形成平搭接。
    translate([-300,split_y-0.1,H-roof_t-joint_gap])
      cube([600,roof_lap_end+joint_gap-split_y+0.1,roof_t/2+joint_gap]);
  }
}
module base_front() {
  union() {
    intersection() { base_plate(); y_region(-300,0); }
    translate([-base_w/2,-0.1,-base_t])
      cube([base_w,base_lap+0.1,base_t/2-joint_gap/2]);
  }
}
module base_back() {
  difference() {
    intersection() { base_plate(); y_region(joint_gap,300); }
    translate([-base_w/2-1,-0.1,-base_t-0.01])
      cube([base_w+2,base_lap+joint_gap+0.1,base_t/2+joint_gap/2+0.01]);
  }
}

// 倾斜绕长边所在的XZ平面展开，保持Y短边余量；支撑由树脂切片软件生成。
// 此处只做旋转，导出脚本将各STL居中并令最低点Z=0。
module shell_resin_pose() { rotate([0,15,0]) rotate([180,0,0]) children(); }
module base_resin_pose() { rotate([0,20,0]) children(); }

module split_assembly(explode=0) {
  color([0.72,0.77,0.84]) translate([0,-explode,0]) shell_front();
  color([0.88,0.73,0.47]) translate([0,explode,0]) shell_back();
  color([0.67,0.74,0.80]) translate([0,-explode,-explode]) base_front();
  color([0.82,0.67,0.43]) translate([0,explode,-explode]) base_back();
}

// ---- 示意件(仅预览) ----
module mini_dummy(){ color("silver") translate([-mini[0]/2, mini_dy-mini[1]/2, 0]) cube(mini); }
module screen_dummy(){ color([0.1,0.1,0.12]) on_face(0, screen_z) translate([-sw/2, -sh/2, -sd]) cube([sw, sh, sd]); color([0.2,0.5,0.9]) on_face(0, screen_z) translate([-sw/2+5, -sh/2+5, 0.2]) cube([sw-10, sh-10, 0.3]); }
module azgti_dummy(){ color("dimgray") translate([0,0,H]) cylinder(d=az_base_d, h=70); color("dimgray") translate([-25,-40,H+70]) cube([50,60,45]); }
module scope_dummy(){ color("burlywood") translate([0,10,H+120]) rotate([-50,0,0]) translate([0,0,-50]) cylinder(d=84, h=190); }
module foot_dummy(){ for (x=[-1,1], y=[-1,1]) translate([x*blk_c, y*blk_c, 0]) color("silver") { translate([0,0,-base_t-14]) cylinder(d=8, h=blk_h+14); translate([0,0,-base_t-20]) cylinder(d=22, h=6); } }
module cord_dummy(){ color("black") on_face(2, 12) translate([30,0,-2]) cylinder(d=6, h=60); }

module assembly(){
  foot_dummy();
  color("burlywood", 0.95) shell();
  color("saddlebrown") base_plate();
  mini_dummy(); screen_dummy(); cord_dummy();
}
if (part=="preview")     split_assembly();
if (part=="exploded")    split_assembly(35);
if (part=="shell_front") shell_front();
if (part=="shell_back") shell_back();
if (part=="base_front") base_front();
if (part=="base_back") base_back();
if (part=="shell_front_print") shell_resin_pose() shell_front();
if (part=="shell_back_print") shell_resin_pose() shell_back();
if (part=="base_front_print") base_resin_pose() base_front();
if (part=="base_back_print") base_resin_pose() base_back();
if (part=="with_mount")  { assembly(); azgti_dummy(); scope_dummy(); }
if (part=="cutaway")     difference(){ assembly(); translate([0,-500,-30]) cube([600,1000,700]); }
if (part=="shell")       shell();
if (part=="shell_print") shell_print();
if (part=="base")        base_plate();
if (part=="base_fdm")     translate([0,0,base_t]) base_plate();
// FDM raised base, NO screws. Plate bottom (z=0) on bed. Four 26x26 posts, 20mm tall,
// grow up from the plate corners and lift the shell. Unit rests on the 4 post tops.
post_h = 20;
module base_legged() {
  base_plate();
  for (x=[-1,1], y=[-1,1])
    translate([x*blk_c-blk/2, y*blk_c-blk/2, 0]) cube([blk,blk,blk_h+post_h]);
}
if (part=="base_legged")  base_legged();
