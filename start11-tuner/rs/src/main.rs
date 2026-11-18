#![windows_subsystem = "windows"]

//! Start11 Tuner (Rust) — конфигуратор Start11 поверх его родных ключей.
//!
//! Start11 хранит все значения строками в
//! HKCU\Software\Stardock\Start8\Start8.ini\Start8 — там же их читаем и пишем.
//! Контролы строятся по фактическому содержимому ключа, поэтому редактор
//! охватывает всё, что Start11 успел записать. Служебные флаги (лицензия, кэш,
//! миграции) пропускаются.
//!
//! Применение: бэкап -> запись только изменённого -> перезапуск explorer.
//! Чего приложение не делает: активации/обхода лицензии, редактора закреплённых
//! (подключи Right/RightMode в неразобранном формате) и редактора цветов.

use std::collections::BTreeMap;

use eframe::egui;
use winreg::enums::{HKEY_CURRENT_USER, KEY_READ, KEY_WRITE};
use winreg::RegKey;

const SUBKEY: &str = r"Software\Stardock\Start8\Start8.ini\Start8";
const CONFIG_EXE: &str = r"C:\Program Files (x86)\Stardock\Start11\Start11Config.exe";

const BG: egui::Color32 = egui::Color32::from_rgb(0x1b, 0x1b, 0x1f);
const SIDE: egui::Color32 = egui::Color32::from_rgb(0x15, 0x15, 0x1a);
const CARD: egui::Color32 = egui::Color32::from_rgb(0x2a, 0x2a, 0x33);
const CARD_HI: egui::Color32 = egui::Color32::from_rgb(0x33, 0x33, 0x3d);
const TEXT: egui::Color32 = egui::Color32::from_rgb(0xe6, 0xe6, 0xef);
const MUTED: egui::Color32 = egui::Color32::from_rgb(0x8a, 0x8a, 0x99);
const ACCENT: egui::Color32 = egui::Color32::from_rgb(0xe0, 0xaf, 0x68);

const STYLES: &[(&str, &str)] = &[
    ("Стиль Windows 7", "Классика Windows 7"),
    ("Стиль Modern", "Обновлённое Windows 7"),
    ("Стиль Windows 10", "Улучшенный Windows 10"),
    ("Стиль Windows 11", "Улучшенный Windows 11"),
    ("Стиль Windows App", "Новый стиль Windows 11"),
];

const NAV: &[&str] = &[
    "Меню «Пуск»",
    "Панель задач",
    "Закреплённые на панели",
    "Поиск",
    "Прочие ключи",
    "Управление",
    "О программе",
];

// служебные: лицензия, кэш, флаги первого запуска и миграций — не настройки
const SKIP: &[&str] = &[
    "LS",
    "TextLookupD",
    "LastSeenOS2",
    "QC",
    "MenuMode",
    "NewInstall",
    "NewInstallDone",
    "StartedOnce",
    "SetupLnk",
    "SetupLnk11",
    "CreatedPinned10",
    "CreatedPinned11",
    "UpgradedRightSide",
    "UpgradedRightSide2",
    "FlushMetro3",
    "FlushMetro4",
    "AskedAboutStartButton2",
    "lRight",
    "StandardStartMenuOLD",
];

enum Kind {
    Bool(bool),
    Int(i32),
    Text(String),
}

struct Row {
    key: String,
    label: String,
    kind: Kind,
}

fn label_of(key: &str) -> &str {
    match key {
        "AcrylicBlurEnabled" => "Акрил / размытие меню",
        "S11_ForceDarkMode" => "Тёмное меню независимо от системы",
        "S11_UseWallpaperEffect" => "Подложка из обоев",
        "UseFormicaEffect" => "Эффект подложки (Formica)",
        "MenuAlphaValue" => "Прозрачность меню, %",
        "BackgroundAlphaValue" => "Прозрачность фона, %",
        "CustomColour" => "Свой цвет меню",
        "CustomColourV" => "Свой цвет меню — значение",
        "CustomColourTextureMenu" => "Свой цвет текстуры меню",
        "FullUITexture" => "Текстура на всё меню",
        "S11_MaxColourOn" => "Кнопка «развернуть» окрашена",
        "S11_MaxColour" => "Цвет кнопки «развернуть»",
        "S11_MaxAlpha" => "Прозрачность кнопки «развернуть»",
        "S11_SchemeFilter" => "Фильтр цветовой схемы",
        "S11_SchemeApplyTo" => "Схема применяется к",
        "S11_MirrorOSChoice" => "Повторять выбор темы системы",
        "ShowRight" => "Правая колонка закреплённых",
        "ShowIconsOnRight" => "Иконки в правой колонке",
        "RightIconMode" => "Крупные иконки справа",
        "TileMode" => "Плитки вместо списка",
        "LockedIcons" => "Заблокировать раскладку иконок",
        "SkinIndex" => "Номер скина",
        "StandardStartMenu" => "Обычное меню Windows вместо Start11",
        "Image" => "Картинка кнопки «Пуск»",
        "EnableS11Taskbar" => "Панель задач Start11",
        "TaskbarOnTop" => "Панель задач сверху",
        "SecondaryTaskbarOnTop" => "Сверху и на втором мониторе",
        "TaskbarDisallowBlur" => "Запретить размытие панели",
        "TaskbarAlphaValue" => "Прозрачность панели, %",
        "CustomColourTaskbar" => "Свой цвет панели",
        "CustomColourTaskbarV" => "Свой цвет панели — значение",
        "S11_TaskbarTextColour" => "Цвет текста на панели",
        "S11_TaskbarFocusColour" => "Цвет активного элемента панели",
        "TaskbarBorderColour" => "Цвет рамки панели",
        "S11_VerticalTBModePrimary" => "Вертикальная панель на основном экране",
        "S11_VerticalTBModeSecondary" => "Вертикальная панель на втором экране",
        "HorzAlignS11Taskbar" => "Выравнивание панели по горизонтали",
        "AllowAlignMiddleStartInternal" => "Кнопки по центру",
        "UseCortanaSearch" => "Веб-поиск Cortana",
        "DisableCharms" => "Отключить панель Charms",
        "Win7StyleSub" => "Отдельные настройки стиля Windows 7",
        "ModernStyleSub" => "Отдельные настройки стиля Modern",
        "Win12Width" => "Ширина меню Windows 11",
        "Win12Height_3" => "Высота меню Windows 11",
        other => other,
    }
}

fn group_of(key: &str) -> usize {
    if key.contains("Taskbar") {
        1
    } else if key.contains("Search") {
        3
    } else if ["Right", "Tile", "Pins", "Icon", "Metro", "Folder"]
        .iter()
        .any(|p| key.contains(p))
    {
        2
    } else if key.starts_with("S11_")
        || [
            "Menu", "Acrylic", "Custom", "Background", "UseFormica", "FullUI", "Texture",
            "Skinned", "Darken",
        ]
        .iter()
        .any(|p| key.starts_with(p))
    {
        0
    } else {
        4
    }
}

fn key(flags: u32) -> std::io::Result<RegKey> {
    RegKey::predef(HKEY_CURRENT_USER).open_subkey_with_flags(SUBKEY, flags)
}

fn read_all() -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Ok(k) = key(KEY_READ) {
        for name in k.enum_values().flatten().map(|(n, _)| n) {
            if let Ok(v) = k.get_value::<String, _>(&name) {
                out.insert(name, v);
            }
        }
    }
    out
}

fn backup_dir() -> std::path::PathBuf {
    let base = std::env::var("LOCALAPPDATA").unwrap_or_else(|_| ".".into());
    std::path::PathBuf::from(base).join("Start11Tuner")
}

fn save_backup() -> Option<String> {
    let dir = backup_dir();
    std::fs::create_dir_all(&dir).ok()?;
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .ok()?
        .as_secs();
    let file = dir.join(format!("backup-{stamp}.json"));
    let data = serde_json::to_vec_pretty(&read_all()).ok()?;
    std::fs::write(&file, data).ok()?;
    Some(file.display().to_string())
}

fn list_backups() -> Vec<String> {
    let mut names: Vec<String> = std::fs::read_dir(backup_dir())
        .map(|rd| {
            rd.flatten()
                .filter_map(|e| e.file_name().into_string().ok())
                .filter(|n| n.starts_with("backup-") && n.ends_with(".json"))
                .collect()
        })
        .unwrap_or_default();
    names.sort();
    names.reverse();
    names
}

fn restore_backup(name: &str) -> usize {
    let file = backup_dir().join(name);
    let Ok(raw) = std::fs::read_to_string(file) else { return 0 };
    let Ok(map) = serde_json::from_str::<BTreeMap<String, String>>(&raw) else { return 0 };
    let Ok(k) = key(KEY_READ | KEY_WRITE) else { return 0 };
    let mut n = 0;
    for (name, value) in map {
        if k.set_value(&name, &value).is_ok() {
            n += 1;
        }
    }
    n
}

struct App {
    groups: [Vec<Row>; 5],
    orig: BTreeMap<String, String>,
    no_start11: bool,
    style: usize,
    style_dirty: bool,
    section: usize,
    status: String,
    backups: Vec<String>,
    selected_backup: usize,
}

impl App {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let mut fonts = egui::FontDefinitions::default();
        if let Ok(bytes) = std::fs::read(r"C:\Windows\Fonts\segoeui.ttf") {
            fonts
                .font_data
                .insert("segoe".into(), std::sync::Arc::new(egui::FontData::from_owned(bytes)));
            for family in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
                if let Some(list) = fonts.families.get_mut(&family) {
                    list.insert(0, "segoe".into());
                }
            }
        }
        cc.egui_ctx.set_fonts(fonts);
        cc.egui_ctx.set_visuals(egui::Visuals::dark());

        let vals = read_all();
        let no_start11 = key(KEY_READ).is_err();
        let mut groups: [Vec<Row>; 5] = Default::default();
        for (name, raw) in &vals {
            if SKIP.contains(&name.as_str()) {
                continue;
            }
            let kind = if raw == "0" || raw == "1" {
                Kind::Bool(raw == "1")
            } else if raw.len() <= 4 && raw.chars().all(|c| c.is_ascii_digit()) {
                Kind::Int(raw.parse().unwrap_or(0))
            } else {
                Kind::Text(raw.clone())
            };
            groups[group_of(name)].push(Row {
                key: name.clone(),
                label: label_of(name).to_string(),
                kind,
            });
        }

        let mut app = App {
            groups,
            orig: vals,
            no_start11,
            style: 0,
            style_dirty: false,
            section: 0,
            status: String::new(),
            backups: list_backups(),
            selected_backup: 0,
        };

        if let Some(mode) = app.orig.get("MenuMode").and_then(|v| v.parse::<usize>().ok()) {
            if (1..=5).contains(&mode) {
                app.style = mode - 1;
            }
        }

        if no_start11 {
            app.status = format!("Start11 не найден: HKCU\\{SUBKEY} — менять нечего.");
            return app;
        }

        let running = std::process::Command::new("tasklist")
            .args(["/FI", "IMAGENAME eq Start11_64.exe", "/NH"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).contains("Start11_64"))
            .unwrap_or(false);

        app.status = "Смена стиля между Windows 10 и Windows 11 требует перезагрузки.".to_string();
        if running {
            app.status.push_str(
                "\nStart11 запущен — он перезапишет значения при выходе. Сначала выключи его меню.",
            );
        }
        app
    }

    fn apply(&mut self) {
        let mut changes: Vec<(String, String)> = Vec::new();
        let mode = (self.style + 1).to_string();
        if self.style_dirty && self.orig.get("MenuMode") != Some(&mode) {
            changes.push(("MenuMode".into(), mode));
        }
        for rows in &self.groups {
            for row in rows {
                let v = match &row.kind {
                    Kind::Bool(b) => (if *b { "1" } else { "0" }).to_string(),
                    Kind::Int(i) => i.to_string(),
                    Kind::Text(s) => s.clone(),
                };
                if self.orig.get(&row.key) != Some(&v) {
                    changes.push((row.key.clone(), v));
                }
            }
        }
        if changes.is_empty() {
            self.status = "Изменений нет — писать нечего.".into();
            return;
        }

        let backup = save_backup();
        let Ok(k) = key(KEY_READ | KEY_WRITE) else {
            self.status = "Не удалось открыть ключ Start11 для записи.".into();
            return;
        };
        let mut written = 0;
        for (name, v) in &changes {
            if k.set_value(name, v).is_ok() {
                written += 1;
            }
        }

        let stop_note = match std::process::Command::new("taskkill")
            .args(["/F", "/IM", "Start11_64.exe"])
            .output()
        {
            Ok(o) if o.status.success() => "",
            _ => " Start11 закрыть не удалось — он может вернуть старые значения.",
        };
        let _ = std::process::Command::new("taskkill")
            .args(["/F", "/IM", "explorer.exe"])
            .output();
        std::thread::sleep(std::time::Duration::from_secs(3));
        let _ = std::process::Command::new("explorer.exe").spawn();
        std::thread::sleep(std::time::Duration::from_secs(4));

        let _ = std::fs::write(
            backup_dir().join("last-apply.txt"),
            format!(
                "wrote={written} backup={}{stop_note}",
                backup.unwrap_or_else(|| "нет".into())
            ),
        );
        std::process::exit(0);
    }

    fn cards(&mut self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            for (i, (name, desc)) in STYLES.iter().enumerate() {
                let (rect, resp) =
                    ui.allocate_exact_size(egui::vec2(140.0, 226.0), egui::Sense::click());
                if resp.clicked() {
                    self.style = i;
                    self.style_dirty = true;
                }
                let selected = self.style == i;
                let painter = ui.painter();
                painter.rect_filled(
                    rect,
                    egui::CornerRadius::same(8),
                    if selected { CARD_HI } else { CARD },
                );
                if selected {
                    painter.rect_stroke(
                        rect,
                        egui::CornerRadius::same(8),
                        egui::Stroke::new(2.0, ACCENT),
                        egui::StrokeKind::Inside,
                    );
                }

                let preview = egui::Rect::from_min_size(
                    rect.min + egui::vec2(14.0, 14.0),
                    egui::vec2(rect.width() - 28.0, 106.0),
                );
                painter.rect_filled(
                    preview,
                    egui::CornerRadius::same(4),
                    egui::Color32::from_rgb(0x3a, 0x3a, 0x46),
                );

                let ink = egui::Color32::from_rgb(0x5a, 0x5a, 0x6b);
                let p = preview.min;
                match i {
                    0 => {
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(6.0, 16.0), egui::vec2(46.0, 22.0)), 2.0, ink);
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(58.0, 16.0), egui::vec2(46.0, 74.0)), 2.0, ink);
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(6.0, 44.0), egui::vec2(46.0, 46.0)), 2.0, ink);
                    }
                    1 => {
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(6.0, 12.0), egui::vec2(98.0, 10.0)), 2.0, ink);
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(6.0, 28.0), egui::vec2(62.0, 66.0)), 2.0, ink);
                        painter.rect_filled(egui::Rect::from_min_size(p + egui::vec2(74.0, 28.0), egui::vec2(30.0, 66.0)), 2.0, ink);
                    }
                    2 => {
                        for r in 0..2 {
                            for c in 0..4 {
                                let pos = p + egui::vec2(6.0 + c as f32 * 26.0, 16.0 + r as f32 * 28.0);
                                painter.rect_filled(egui::Rect::from_min_size(pos, egui::vec2(22.0, 22.0)), 2.0, ink);
                            }
                        }
                    }
                    3 => {
                        for r in 0..3 {
                            for c in 0..5 {
                                let pos = p + egui::vec2(8.0 + c as f32 * 20.0, 18.0 + r as f32 * 24.0);
                                painter.rect_filled(egui::Rect::from_min_size(pos, egui::vec2(16.0, 18.0)), 2.0, ink);
                            }
                        }
                    }
                    _ => {
                        for r in 0..4 {
                            let pos = p + egui::vec2(8.0, 16.0 + r as f32 * 14.0);
                            painter.rect_filled(egui::Rect::from_min_size(pos, egui::vec2(96.0, 8.0)), 2.0, ink);
                        }
                    }
                }

                painter.text(
                    rect.min + egui::vec2(12.0, 132.0),
                    egui::Align2::LEFT_TOP,
                    *name,
                    egui::FontId::proportional(13.0),
                    if selected { ACCENT } else { TEXT },
                );
                painter.text(
                    rect.min + egui::vec2(12.0, 178.0),
                    egui::Align2::LEFT_TOP,
                    *desc,
                    egui::FontId::proportional(11.0),
                    MUTED,
                );
            }
        });
    }

    fn rows(&mut self, ui: &mut egui::Ui) {
        if self.no_start11 {
            ui.label(
                egui::RichText::new(
                    "Start11 не установлен или ещё ни разу не запускался.\n\
                     Нет ключа HKCU\\Software\\Stardock\\Start8\\Start8.ini\\Start8 — \
                     настраивать нечего.",
                )
                .color(MUTED),
            );
            return;
        }
        let rows = &mut self.groups[self.section];
        if rows.is_empty() {
            ui.label(
                egui::RichText::new("Start11 ещё не записывал ключи для этого раздела.")
                    .color(MUTED),
            );
            return;
        }
        egui::ScrollArea::vertical()
            .id_salt(self.section)
            .auto_shrink([false, false])
            .show(ui, |ui| {
                egui::Grid::new("rows")
                    .num_columns(2)
                    .spacing([16.0, 8.0])
                    .show(ui, |ui| {
                        for row in rows {
                            ui.label(row.label.clone()).on_hover_text(&row.key);
                            match &mut row.kind {
                                Kind::Bool(v) => {
                                    ui.add(egui::Checkbox::without_text(v))
                                        .on_hover_text(&row.key);
                                }
                                Kind::Int(v) => {
                                    ui.add(egui::DragValue::new(v).range(0..=9999));
                                }
                                Kind::Text(s) => {
                                    ui.add(egui::TextEdit::singleline(s).desired_width(360.0));
                                }
                            }
                            ui.end_row();
                        }
                    });
            });
    }

    fn manage(&mut self, ui: &mut egui::Ui) {
        ui.label(egui::RichText::new("Бэкапы").color(MUTED));
        let names = self.backups.clone();
        egui::ComboBox::from_id_salt("backups")
            .width(320.0)
            .selected_text(
                names
                    .get(self.selected_backup)
                    .cloned()
                    .unwrap_or_else(|| "нет бэкапов".into()),
            )
            .show_ui(ui, |ui| {
                for (i, n) in names.iter().enumerate() {
                    ui.selectable_value(&mut self.selected_backup, i, n);
                }
            });
        if ui.button("Восстановить выбранный").clicked() {
            if let Some(name) = self.backups.get(self.selected_backup) {
                let n = restore_backup(name);
                self.status = format!("Восстановлено значений: {n} из {name}. Нужна перезагрузка.");
            } else {
                self.status = "Бэкапов пока нет.".into();
            }
        }
        if ui.button("Открыть папку бэкапов").clicked() {
            let _ = std::process::Command::new("explorer.exe")
                .arg(backup_dir())
                .spawn();
        }
        if ui.button("Открыть настройки Start11").clicked() {
            let _ = std::process::Command::new(CONFIG_EXE).spawn();
        }
        ui.add_space(8.0);
        ui.label(
            egui::RichText::new(
                "Перед применением выключи меню Start11: работающий процесс перезаписывает настройки при выходе.",
            )
            .color(MUTED),
        );
    }
}

impl eframe::App for App {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::SidePanel::left("nav")
            .exact_width(230.0)
            .resizable(false)
            .frame(egui::Frame::NONE.fill(SIDE))
            .show(ctx, |ui| {
                ui.add_space(24.0);
                for (i, name) in NAV.iter().enumerate() {
                    let selected = self.section == i;
                    let resp = ui.add_sized(
                        [230.0, 40.0],
                        egui::SelectableLabel::new(
                            selected,
                            egui::RichText::new(*name).color(if selected { TEXT } else { MUTED }),
                        ),
                    );
                    if resp.clicked() {
                        self.section = i;
                    }
                }
            });

        egui::TopBottomPanel::bottom("footer")
            .exact_height(80.0)
            .frame(egui::Frame::NONE.fill(BG))
            .show(ctx, |ui| {
                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    ui.label(egui::RichText::new(&self.status).color(MUTED).size(12.0));
                });
                ui.add_space(4.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    let apply = egui::Button::new(egui::RichText::new("Применить").color(BG))
                        .fill(ACCENT)
                        .min_size(egui::vec2(160.0, 34.0));
                    if ui.add_enabled(!self.no_start11, apply).clicked() {
                        self.apply();
                    }
                    let revert = egui::Button::new(egui::RichText::new("Откатить").color(TEXT))
                        .fill(CARD)
                        .min_size(egui::vec2(160.0, 34.0));
                    if ui.add(revert).clicked() {
                        if let Some(name) = self.backups.first().cloned() {
                            let n = restore_backup(&name);
                            self.status =
                                format!("Откат из {name}: {n} значений. Перезагрузись, чтобы применилось.");
                        } else {
                            self.status = "Бэкапов пока нет.".into();
                        }
                    }
                });
            });

        egui::CentralPanel::default()
            .frame(egui::Frame::NONE.fill(BG).inner_margin(egui::Margin {
                left: 24,
                right: 24,
                top: 20,
                bottom: 0,
            }))
            .show(ctx, |ui| {
                ui.label(
                    egui::RichText::new(NAV[self.section])
                        .size(24.0)
                        .strong()
                        .color(TEXT),
                );
                ui.add_space(10.0);
                match self.section {
                    0..=4 => {
                        if self.section == 0 {
                            ui.label(egui::RichText::new("Стиль меню «Пуск»").color(MUTED));
                            ui.add_space(6.0);
                            self.cards(ui);
                            ui.add_space(12.0);
                        }
                        self.rows(ui);
                    }
                    5 => self.manage(ui),
                    _ => {
                        ui.label(
                            egui::RichText::new("Start11 Tuner")
                                .size(16.0)
                                .color(TEXT),
                        );
                        ui.add_space(6.0);
                        ui.label(
                            egui::RichText::new(
                                "Отдельный редактор настроек Start11. Собран на Rust, \
                                 зависимостей и внешних скриптов нет.\n\n\
                                 Ключ: HKCU\\Software\\Stardock\\Start8\\Start8.ini\\Start8\n\
                                 Значения хранятся строками, булевы — \"0\"/\"1\".\n\n\
                                 Пишутся только изменённые значения. Перед записью — бэкап \
                                 в %LOCALAPPDATA%\\Start11Tuner.\n\
                                 «Применить» перезапускает explorer и закрывает окно; \
                                 перезагрузка нужна только при смене стиля 10 ↔ 11.\n\n\
                                 Не делает: активацию и обход лицензии, редактор закреплённых.",
                            )
                            .color(MUTED),
                        );
                    }
                }
            });
    }
}

fn main() -> eframe::Result<()> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1040.0, 660.0])
            .with_resizable(false),
        ..Default::default()
    };
    eframe::run_native(
        "Start11 Tuner",
        options,
        Box::new(|cc| Ok(Box::new(App::new(cc)))),
    )
}
