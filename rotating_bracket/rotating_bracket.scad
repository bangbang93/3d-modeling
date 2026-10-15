// ============================================================
//  旋转支架装置 — Rotating Bracket
//  参数化 OpenSCAD 模型
//  分件打印：底座（含轴+限位杆）/ 旋转杆 / 压扣盖
// ============================================================

// ===== 参数定义 =====

// 底座参数
base_length = 50;       // mm  底座长度（X 轴）
base_width  = 50;       // mm  底座宽度（Y 轴）
base_height = 3;        // mm  底座厚度

// 旋转杆参数
rod_length   = 200;     // mm  旋转杆总长度
rod_diameter = 8;       // mm  旋转杆截面边长

// 中心轴参数
center_shaft_d = 12;    // mm  轴直径
center_shaft_h = 14;    // mm  轴高度（轴 hub_h + cap_h 余量）

// 限位杆参数
limit_rod_d  = 6;       // mm  限位杆直径
limit_rod_h  = 10;      // mm  限位杆高度（与 hub 齐平即可）

// 配合参数
bore_clearance = 0.2;   // mm  轴孔旋转间隙（单边）
cap_press_fit  = 0.25;  // mm  压扣盖过盈量（单边，压紧用）
cap_h          = 3;     // mm  压扣盖厚度
$fn            = 64;

// 预览参数
preview_angle = 45;     // °   装配预览时旋转杆的角度（0–180）
show_assembly = false;   // true=装配预览 / false=打印排版

// ===== 辅助模块 =====

// 圆角长方体（所有 8 个角均圆化）
//   lx：X 方向长度（从 x=0 延伸到 x=lx）
//   ly/lz：Y/Z 方向宽度（关于原点对称）
//   r：圆角半径
module rounded_cuboid(lx, ly, lz, r) {
    hull() {
        for (xi = [r, lx - r])
        for (yi = [-ly/2 + r, ly/2 - r])
        for (zi = [-lz/2 + r, lz/2 - r])
            translate([xi, yi, zi])
                sphere(r = r, $fn = 16);
    }
}

// ===== 内部派生尺寸 =====

// 限位杆中心到底座中心的距离（不超出底座边界）
_limit_r = min(rod_length / 2,
               base_length / 2 - limit_rod_d / 2 - 1);

// 限位角（自动计算）：使旋转杆恰好停在水平位置（0° 和 180°）
//   _stop_angle = atan((rod_diameter/2 + limit_rod_d/2) / _limit_r)
//   限位杆1 在 -_stop_angle   → 挡住杆在 0°（+X 水平）时的 -Y 边缘
//   限位杆2 在 180°-_stop_angle → 挡住杆在 180°（-X 水平）时的 +Y 边缘
_stop_angle = atan((rod_diameter / 2 + limit_rod_d / 2) / _limit_r);

// 旋转杆套孔内径（单边 bore_clearance 间隙，旋转顺滑）
_rod_bore_d = center_shaft_d + 2 * bore_clearance;

// ============================================================
// ===== 模块定义 =====
// ============================================================

// ------------------------------------------------------------
// 底座平板（无孔，一体化底座的基础）
// ------------------------------------------------------------
module base() {
    cube([base_length, base_width, base_height], center = true);
}

// ------------------------------------------------------------
// 中心轴
//   纯圆柱销，与底座一体，旋转杆套在其上
//   压扣盖从顶端压入固定旋转杆
// ------------------------------------------------------------
module center_shaft() {
    cylinder(d = center_shaft_d, h = center_shaft_h);
}

// ------------------------------------------------------------
// 限位杆（单根）
//   从底座顶面直接生长，无插入段
// ------------------------------------------------------------
module single_limit_rod() {
    cylinder(d = limit_rod_d, h = limit_rod_h);
}

// ------------------------------------------------------------
// 两根限位杆（组合）
//   对称布置在 ±stop_angle 处
// ------------------------------------------------------------
module limit_rods() {
    // 两根限位杆均在 0°–180° 行程范围的外侧：
    //   杆1 在 -_stop_angle      → 0°（+X 水平）的 CW 外侧
    //   杆2 在 180°+_stop_angle  → 180°（-X 水平）的 CCW 外侧
    for (a = [-_stop_angle, 180 + _stop_angle]) {
        translate([
            _limit_r * cos(a),
            _limit_r * sin(a),
            0
        ])
            single_limit_rod();
    }
}

// ------------------------------------------------------------
// 压扣盖
//   从顶端压入中心轴，固定旋转杆防止脱落
//   内孔过盈 cap_press_fit mm（单边），需用力按压到位
//   底部倒角引导对准
// ------------------------------------------------------------
module retaining_cap() {
    cap_outer_d = center_shaft_d + 6;              // 外径，足以覆盖 hub 孔
    cap_inner_d = center_shaft_d - 2 * cap_press_fit;  // 过盈内孔

    difference() {
        cylinder(d = cap_outer_d, h = cap_h);
        // 过盈压配孔
        translate([0, 0, -0.1])
            cylinder(d = cap_inner_d, h = cap_h + 0.2);
        // 底部引导倒角（便于对准轴顶）
        translate([0, 0, -0.1])
            cylinder(d1 = center_shaft_d + 0.6, d2 = cap_inner_d,
                     h = min(1.5, cap_h * 0.5));
    }
}

// ------------------------------------------------------------
// 旋转杆
//   单侧延伸的圆角长方体杆，hub 端套住中心轴，绕 Z 轴旋转
//   杆从 hub 边缘向 +X 方向单向延伸 rod_length
//   截面为圆角正方形（rod_diameter × rod_diameter）
// ------------------------------------------------------------
module rotating_rod() {
    hub_d    = center_shaft_d + 8;           // hub 外径（包裹中心轴）
    hub_h    = rod_diameter;                 // hub 高度 = 杆截面高度，平躺打印不悬空
    r_corner = max(1.0, rod_diameter * 0.2); // 圆角半径

    // 杆体从 hub 内部开始，与 hub 有充分重叠，保证 union 连成一体
    rod_body_x = hub_d / 2 - rod_diameter;  // 向 hub 内延伸一个杆宽
    rod_body_l = rod_length - rod_body_x;   // 延伸到 x = rod_length 处

    difference() {
        union() {
            // 中心套筒（圆柱）
            cylinder(d = hub_d, h = hub_h, center = true);

            // 单侧圆角长方体杆（从 hub 内部向 +X 延伸，保证与 hub 充分重叠）
            translate([rod_body_x, 0, 0])
                rounded_cuboid(
                    rod_body_l,
                    rod_diameter,
                    rod_diameter,
                    r_corner
                );
        }

        // 套孔：贯穿整个 hub 高度
        cylinder(d = _rod_bore_d, h = hub_h + 0.2, center = true);
    }
}

// ============================================================
// ===== 一体化底座模块 =====
// ============================================================

// base_unit() — 底座 + 中心轴 + 限位杆 三合一实体
//   全部从底面 Z=0 生长，一次打印成型，无需组装
module base_unit() {
    union() {
        // 底座平板（以底面 Z=0 为基准）
        translate([0, 0, base_height / 2])
            base();

        // 中心轴：从底座顶面向上生长
        translate([0, 0, base_height])
            center_shaft();

        // 两根限位杆：从底座顶面向上生长
        translate([0, 0, base_height])
            limit_rods();
    }
}

// ============================================================
// ===== 装配模块 =====
// ============================================================

// assembly() — 预览完整装配状态（含压扣盖）
//   angle → 旋转杆预览角度
module assembly(angle = 0) {
    hub_h = rod_diameter;  // 与 rotating_rod 内保持一致

    // 一体化底座（含中心轴与限位杆）
    color("SteelBlue", 0.9)
        base_unit();

    // 旋转杆：hub 底面落在底座顶面，hub 以中心 Z 轴对称
    rod_z = base_height + hub_h / 2;
    translate([0, 0, rod_z])
        rotate([0, 0, angle])
            color("Coral", 0.9)
                rotating_rod();

    // 压扣盖：压在轴顶
    translate([0, 0, base_height + center_shaft_h])
        color("Gold", 0.9)
            retaining_cap();
}

// ============================================================
// ===== 打印排版模块 =====
// ============================================================

// print_parts() — 3 件平铺，全部无悬空，直接切片
//   件1（左）：底座+轴+限位杆一体
//   件2（右）：旋转杆（平躺，hub 侧面接触床面）
//   件3（右上）：压扣盖（平躺）
module print_parts() {
    gap = 20;

    // 件1：底座一体件（底面朝下）
    color("SteelBlue")
        base_unit();

    // 件2：旋转杆（hub 中心居中，杆向 +X 延伸，平躺打印）
    translate([0, base_width / 2 + rod_diameter / 2 + gap, 0])
        color("Coral")
            rotating_rod();

    // 件3：压扣盖（平躺，置于件2旁侧）
    cap_outer_d = center_shaft_d + 6;
    translate([0, base_width / 2 + rod_diameter + cap_outer_d / 2 + gap * 2, 0])
        color("Gold")
            retaining_cap();
}

// ============================================================
// ===== 执行入口 =====
// ============================================================

if (show_assembly) {
    assembly(angle = preview_angle);
} else {
    print_parts();
}

// ============================================================
// ===== 快速测试：取消注释以单独预览某个模块 =====
// ============================================================
// base_unit();
// rotating_rod();
// retaining_cap();
// assembly(angle = 45);
// print_parts();
