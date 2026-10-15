// 四个垫块：与原底板角块同尺寸同孔位，只是更高。垫在原底板下面把整机顶高。
// 26x26, 高 = blk_h(12, 与原块顶面对齐用) + post_h(20 垫高) = 32
// 中心 M8 竖孔(脚,Ø8.6通孔+顶部螺母槽), 侧面 M3 底孔(Ø2.5), 与原块一致。
blk=26; blk_h=12; post_h=20; blk_c=86;
lf_nut_af=13.0; lf_nut_h=6.5; lf_hole=8.6;
m3_pilot=2.5; m3_z=6; m3_off=10;
H = blk_h+post_h;   // 32
module post(){
  difference(){
    cube([blk,blk,H]);
    // M8 竖孔：从下往上通孔 + 顶部螺母槽（螺母从上放）
    translate([blk/2,blk/2,-1]) cylinder(d=lf_hole,h=H+2,$fn=48);
    translate([blk/2,blk/2,H-lf_nut_h-0.5]) cylinder(d=(lf_nut_af+0.4)/cos(30),h=lf_nut_h+1,$fn=6);
    // M3 底孔从侧面进（与原块同侧同高）
    translate([blk/2, m3_off+blk/2-blk/2, m3_z]) rotate([0,90,0]) translate([-blk/2,0,0])
      translate([blk/2,0,0]) cylinder(d=m3_pilot,h=blk+2,center=true,$fn=32);
  }
}
for(x=[0,1],y=[0,1]) translate([x*(blk+4),y*(blk+4),0]) post();
