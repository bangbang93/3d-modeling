// ============================================================
//  旋转支架装置 — Rotating Bracket
//  参数化 OpenSCAD 模型
//  支持分件打印(parts)与PIP一体打印(pip)两种模式
// ============================================================

// ===== 参数定义 =====

// 底座参数
base_length = 50;       // mm  底座长度（X 轴）
base_width  = 50;       // mm  底座宽度（Y 轴）
base_height = 3;        // mm  底座厚度

// 旋转杆参数
rod_length   = 200;     // mm  旋转杆总长度
rod_diameter = 8;       // mm  旋转杆直径（推荐 6–8）

// 中心轴参数
center_shaft_d = 12;    // mm  中心轴外径（旋转杆套在其上）
center_shaft_h = 25;    // mm  中心轴总高度（含底座段）

// 限位杆参数
limit_rod_d  = 6;       // mm  限位杆直径
limit_rod_h  = 20;      // mm  限位杆高度（露出底座部分）

// 打印参数
print_mode   = "pip";   // "parts" 分件打印 / "pip" 一体打印
assembly_gap = 0.3;     // mm  PIP 运动间隙（单边）
$fn          = 64;

// 预览参数
preview_angle  = 45;    // °   预览时旋转杆的旋转角度（0–180）
show_exploded  = true;  // 爆炸视图开关（仅 parts 模式有效）

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

// 旋转杆套孔内径（rotating_rod 上的孔，套住中心轴）
//   PIP：加间隙可旋转；分件：轻松滑配
_rod_bore_d = (print_mode == "pip")
    ? center_shaft_d + 2 * assembly_gap
    : center_shaft_d + 0.2;

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
//   下部插入底座孔（或 PIP 中浮动），上部为旋转杆的旋转支撑
//   顶端有防脱凸缘
// ------------------------------------------------------------
module center_shaft() {
    flange_d = center_shaft_d + 4;   // 顶端凸缘直径，防止旋转杆脱落
    flange_h = 2;
    body_h   = center_shaft_h - flange_h;

    union() {
        // 主柱
        cylinder(d = center_shaft_d, h = body_h);
        // 顶端凸缘
        translate([0, 0, body_h])
            cylinder(d = flange_d, h = flange_h);
    }
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
// 旋转杆
//   单侧延伸的圆角长方体杆，hub 端套住中心轴，绕 Z 轴旋转
//   杆从 hub 边缘向 +X 方向单向延伸 rod_length
//   截面为圆角正方形（rod_diameter × rod_diameter）
// ------------------------------------------------------------
module rotating_rod() {
    hub_d    = center_shaft_d + 8;          // hub 外径（包裹中心轴）
    hub_h    = rod_diameter * 1.6;           // hub 高度（hub 以 Z=0 为中心）
    r_corner = max(1.0, rod_diameter * 0.2); // 圆角半径

    rod_start  = hub_d / 2;                 // 杆体从 hub 边缘开始
    rod_body_l = rod_length - rod_start;    // 杆体有效长度

    difference() {
        union() {
            // 中心套筒（圆柱）
            cylinder(d = hub_d, h = hub_h, center = true);

            // 单侧圆角长方体杆（向 +X 延伸）
            translate([rod_start, 0, 0])
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

// assembly() — 预览装配状态
//   exploded=true → 爆炸图，旋转杆沿 Z 轴上移
//   angle         → 旋转杆预览角度
module assembly(exploded = false, angle = 0) {
    exp = exploded ? 1 : 0;

    // 一体化底座（含中心轴与限位杆）
    color("SteelBlue", 0.9)
        base_unit();

    // 旋转杆：套在中心轴上，居中于轴体中段
    rod_z = base_height
          + center_shaft_h * 0.45
          + exp * 35;
    translate([0, 0, rod_z])
        rotate([0, 0, angle])
            color("Coral", 0.9)
                rotating_rod();
}

// ============================================================
// ===== 打印输出模块 =====
// ============================================================

// ------------------------------------------------------------
// 分件打印排版
//   共 2 件：一体底座、旋转杆
// ------------------------------------------------------------
module print_parts() {
    gap = 20;

    // 一体底座（底面朝下，原位）
    color("SteelBlue")
        base_unit();

    // 旋转杆（平放，hub 中心向 +Y 偏移，杆向 +X 延伸）
    translate([0, base_width / 2 + rod_diameter / 2 + gap, 0])
        color("Coral")
            rotating_rod();
}

// ------------------------------------------------------------
// PIP 一体打印输出
//   底座+轴+限位杆 作为一体固定件，旋转杆浮动其上
//   运动间隙已内嵌在 _rod_bore_d 中
// ------------------------------------------------------------
module print_pip() {
    // 一体固定件
    color("SteelBlue", 0.9)
        base_unit();

    // 旋转杆（浮动，gap 已含在套孔内径里）
    //   hub 中心高度：底座顶面 + 轴体中段 + assembly_gap 确保底面不贴合
    translate([0, 0, base_height + center_shaft_h * 0.45])
        rotate([0, 0, preview_angle])
            color("Coral", 0.9)
                rotating_rod();
}

// ============================================================
// ===== 执行入口 — 根据 print_mode 自动切换 =====
// ============================================================

if (print_mode == "parts") {
    if (show_exploded) {
        assembly(exploded = true, angle = preview_angle);
    } else {
        print_parts();
    }
} else if (print_mode == "pip") {
    print_pip();
}

// ============================================================
// ===== 快速测试：取消注释以单独预览某个模块 =====
// ============================================================
// base_unit();
// rotating_rod();
// assembly(exploded = false, angle = 45);
// assembly(exploded = true,  angle = 45);
