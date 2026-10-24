// ============================================================
//  86型插座防泼溅挡板（兼容漏电保护插头）— Outlet Splash Guard
//  参数化 OpenSCAD 模型
//
//  用途：贴装于 86 型插座面板外侧，防止自上而下的泼溅水
//        顺墙面流入插座。顶部雨棚 + 滴水沿将水流引导至
//        插头前方排走；前下方完全敞开，兼容带漏电保护
//        插头（热水器等）的大体积插头的插拔、散热与排水。
//
//  安装：裙边背面用 3M VHB 胶带/结构胶粘贴于面板边缘
//        与墙面；上方挡板预留 2 个膨胀管孔，可选打钉
//        加固。窗口正中露出面板，原面板固定螺丝仍可
//        正常拆装。
//
//  打印：前缘朝下平放打印，全程无支撑；顶部一层裙边
//        存在约 100mm 桥接，切片器默认桥接设置即可。
// ============================================================

// ===== 参数定义 =====

/* [86 面板与贴合] */
face_w    = 86;      // mm  86 型面板宽度
face_h    = 86;      // mm  86 型面板高度
clearance = 2;       // mm  窗口单边间隙
margin    = 11;      // mm  贴合裙边单边宽度（粘贴面）
flange_t  = 3;       // mm  裙边厚度
corner_r  = 10;      // mm  裙边外圆角
win_r     = 4;       // mm  窗口圆角

/* [可选加固] */
anchor_holes = true;
anchor_d  = 6;       // mm  M4/M5 膨胀管预埋孔直径
anchor_x  = 30;      // mm  锚孔横向间距（对称分布）
anchor_y  = 103;     // mm  锚孔高度（须在挡水沿实心区内，避开顶棚线）

/* [罩体] */
wall_t    = 3;       // mm  侧壁厚
depth     = 78;      // mm  罩体总深（内腔深 ≈ depth - flange_t）
vent_slots = true;   //     侧壁下部通风槽（位置低，顶部泼溅不会灌入）
vent_w    = 4;       // mm  通风槽宽（沿深度方向）
vent_h    = 18;      // mm  通风槽高（沿高度方向）
vent_y0   = -38;     // mm  通风槽下沿高度（相对面板中心）
vent_z0   = 30;      // mm  通风槽起始深度
vent_n    = 3;       //     每侧通风槽数量
vent_pitch = 12;     // mm  通风槽间距

/* [顶棚] */
roof_slope = 25;     // °   顶棚下倾角（引导水流向前往下排）
roof_t     = 3.5;    // mm  顶棚法向厚度
drip_clear = 18;     // mm  滴水沿距面板上沿的净高
drip_lip   = 10;     // mm  滴水沿下翻边高度（截断水膜回流）
upstand_h  = 12;     // mm  贴墙挡水沿高出顶棚的高度

/* [输出] */
print_orientation = true;  // true=打印姿态（前缘朝下）/ false=上墙姿态

// ===== 内部参数（一般无需修改） =====
overlap = 1;   // mm  侧壁顶缘埋入顶棚的重叠量（消除共面布尔退化，
               //      必须小于顶棚垂直向等效厚度）
$fn = 64;

// ===== 内部派生尺寸 =====

_outer_w = face_w + 2 * margin;    // 裙边外宽（=外高）
_win_w   = face_w + 2 * clearance; // 窗口边长
_half_w  = _outer_w / 2;

_tan     = tan(roof_slope);
_y_high  = face_h / 2 + drip_clear + depth * _tan;  // 顶棚顶面贴墙处高度
_y_drip  = _y_high - depth * _tan;                  // 滴水沿顶面高度
_t_v     = roof_t / cos(roof_slope);                // 顶棚垂直向等效厚度
_y_u_0   = _y_high - _t_v;                          // 顶棚底面高度 @ z=0
_y_u_d   = _y_u_0 - depth * _tan;                   // 顶棚底面高度 @ z=depth
_y_u_lip = _y_u_0 - (depth - roof_t) * _tan;        // 顶棚底面高度 @ 滴水沿内侧
_seal_top = _y_high + upstand_h;                    // 挡水沿顶部高度

echo(str("外廓: ", _outer_w, " x ", _seal_top + _half_w, " x ", depth,
         " mm  内腔: ", _outer_w - 2 * wall_t, " x ", depth - flange_t, " mm"));

// ===== 辅助模块 =====

// 圆角矩形（关于原点对称）
module rrect(w, h, r) {
    offset(r = r) offset(delta = -r) square([w, h], center = true);
}

// 沿 X 向拉伸 (wall_z, wall_y) 平面轮廓
//   pts: [[z, y], ...]，拉伸后轮廓位于 x ∈ [x0, x1]
//   映射：轮廓 u=wall_z → 世界 Z，v=wall_y → 世界 Y，拉伸 w → 世界 X
module extrude_profile(pts, x0, x1) {
    translate([x0, 0, 0])
        multmatrix([[0, 0, 1, 0],
                    [0, 1, 0, 0],
                    [1, 0, 0, 0]])
            linear_extrude(height = x1 - x0)
                polygon(points = pts);
}

// ===== 部件模块 =====

// 贴墙裙边：环绕面板的框 + 面板上方的实心挡板（含挡水沿）
module flange_plate() {
    linear_extrude(height = flange_t) {
        difference() {
            union() {
                rrect(_outer_w, _outer_w, corner_r);
                translate([0, (_win_w / 2 + _seal_top) / 2, 0])
                    rrect(_outer_w, _seal_top - _win_w / 2, corner_r);
            }
            rrect(_win_w, _win_w, win_r);
        }
    }
}

// 顶棚：下倾雨棚 + 前端滴水沿，横跨整个宽度
module roof_body() {
    pts = [
        [0,        _y_high],                      // 贴墙处顶面
        [depth,    _y_drip],                      // 滴水沿顶面外缘
        [depth,    _y_drip - drip_lip],           // 滴水沿外沿向下翻
        [depth - roof_t, _y_drip - drip_lip],     // 滴水沿内侧
        [depth - roof_t, _y_u_lip],            // 回到顶棚底面
        [0,        _y_high - _t_v],               // 贴墙处底面
    ];
    extrude_profile(pts, -_half_w, _half_w);
}

// 侧壁：顶缘抬高 overlap 埋入顶棚体内，前后贯通到前缘
module side_walls() {
    pts = [
        [0,     -_half_w],
        [depth, -_half_w],
        [depth, _y_u_d + overlap],
        [0,     _y_u_0 + overlap],
    ];
    extrude_profile(pts, _half_w - wall_t, _half_w);
    mirror([1, 0, 0])
        extrude_profile(pts, _half_w - wall_t, _half_w);
}

// ===== 开孔 =====

// 锚孔：贯穿上方实心挡板（避开窗口、顶棚与侧壁，仅削裙边）
module anchor_holes_cut() {
    for (sx = [-1, 1])
        translate([sx * anchor_x, anchor_y, -0.1])
            cylinder(d = anchor_d, h = flange_t + 0.1);
}

// 侧壁下部通风槽
module vent_slots_cut() {
    for (i = [0 : vent_n - 1])
        for (side = [-1, 1])
            translate([side * (_half_w - wall_t - 1), vent_y0,
                       vent_z0 + i * vent_pitch])
                cube([wall_t + 2, vent_h, vent_w]);
}

// ===== 整体 =====

module splash_guard() {
    difference() {
        union() {
            // 锚孔只开在裙边上，避免切割器咬伤上方侧壁
            difference() {
                flange_plate();
                if (anchor_holes) anchor_holes_cut();
            }
            roof_body();
            side_walls();
        }
        if (vent_slots) vent_slots_cut();
    }
}

// ===== 执行入口 =====

if (print_orientation) {
    // 打印姿态：前缘（含滴水沿）朝下，无支撑
    translate([0, 0, depth]) rotate([0, 180, 0]) splash_guard();
} else {
    // 上墙姿态：Z 轴为出墙方向
    splash_guard();
}

// ===== 快速测试：取消注释以单独预览某个模块 =====
// splash_guard();
