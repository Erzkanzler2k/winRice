#![windows_subsystem = "windows"]

//! Start11 Tuner (Rust) — конфигуратор Start11 поверх его родных ключей.
//!
//! Все значения Start11 хранит строками в
//! HKCU\Software\Stardock\Start8\Start8.ini\Start8 — там же их читаем и пишем.
//! Перед записью делается бэкап в %LOCALAPPDATA%\Start11Tuner.
//!
//! Чего приложение не делает: активации/обхода лицензии, редактора закреплённых
//! (подключи Right/RightMode в неразобранном формате) и редактора цветов.

use std::collections::BTreeMap;
use std::path::PathBuf;

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

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Bool,
    Int,
}

struct Item {
    kind: Kind,
    key: &'static str,
    label: &'static str,
    min: i32,
    max: i32,
}

struct Section {
    name: &'static str,
    items: &'static [Item],
}

const STYLES: &[(&str, &str)] = &[
    ("Стиль Windows 7", "Классическое меню Windows 7."),
    ("Стиль Modern", "Обновлённый стиль Windows 7."),
    ("Стиль Windows 10", "Стиль Windows 10 с улучшениями."),
    ("Стиль Windows 11", "Стиль Windows 11 с улучшениями."),
    ("Стиль Windows App", "Обновлённый стиль Windows 11."),
];

const SECTIONS: &[Section] = &[
    Section {
        name: "Меню «Пуск»",
        items: &[
            Item { kind: Kind::Bool, key: "AcrylicBlurEnabled", label: "Акрил / размытие меню", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "S11_ForceDarkMode", label: "Тёмное меню независимо от системы", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "S11_UseWallpaperEffect", label: "Подложка из обоев", min: 0, max: 1 },
            Item { kind: Kind::Int, key: "MenuAlphaValue", label: "Прозрачность меню", min: 0, max: 100 },
        ],
    },
    Section {
        name: "Панель задач",
        items: &[
            Item { kind: Kind::Bool, key: "EnableS11Taskbar", label: "Панель задач Start11", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "TaskbarOnTop", label: "Панель сверху", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "SecondaryTaskbarOnTop", label: "Сверху и на втором мониторе", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "TaskbarDisallowBlur", label: "Запретить размытие", min: 0, max: 1 },
            Item { kind: Kind::Int, key: "TaskbarAlphaValue", label: "Прозрачность панели", min: 0, max: 100 },
        ],
    },
    Section {
        name: "Закреплённые на панели",
        items: &[
            Item { kind: Kind::Bool, key: "ShowRight", label: "Правая колонка закреплённых", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "ShowIconsOnRight", label: "Иконки в правой колонке", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "TileMode", label: "Плитки вместо списка", min: 0, max: 1 },
            Item { kind: Kind::Bool, key: "RightIconMode", label: "Крупные иконки справа", min: 0, max: 1 },
        ],
    },
    Section {
        name: "Поиск",
        items: &[Item { kind: Kind::Bool, key: "UseCortanaSearch", label: "Веб-поиск Cortana", min: 0, max: 1 }],
    },
];

const NAV: &[&str] = &[
    "Меню «Пуск»",
    "Панель задач",
    "Закреплённые на панели",
    "Поиск",
    "Управление",
    "О программе",
];

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

fn backup_dir() -> PathBuf {
    let base = std::env::var("LOCALAPPDATA").unwrap_or_else(|_| ".".into());
    PathBuf::from(base).join("Start11Tuner")
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
    toggles: BTreeMap<&'static str, bool>,
    nums: BTreeMap<&'static str, i32>,
    missing: BTreeMap<&'static str, bool>,
    style: usize,
    section: usize,
    status: String,
    backups: Vec<String>,
    selected_backup: usize,
}

impl App {
    fn new(cc: &eframe::CreationContext<'_>) -> Self {
        let mut fonts = egui::FontDefinitions::default();
        if let Ok(bytes) = std::fs::read(r"C:\Windows\Fonts\segoeui.ttf") {
            fonts.font_data.insert("segoe".into(), egui::FontData::from_owned(bytes));
            for family in [egui::FontFamily::Proportional, egui::FontFamily::Monospace] {
                if let Some(list) = fonts.families.get_mut(&family) {
                    list.insert(0, "segoe".into());
                }
            }
        }
        cc.egui_ctx.set_fonts(fonts);
        cc.egui_ctx.set_visuals(egui::Visuals::dark());

        let vals = read_all();
        let mut app = App {
            toggles: BTreeMap::new(),
            nums: BTreeMap::new(),
            missing: BTreeMap::new(),
            style: 0,
            section: 0,
            status: String::new(),
            backups: list_backups(),
            selected_backup: 0,
        };

        for section in SECTIONS {
            for item in section.items {
                let raw = vals.get(item.key);
                app.missing.insert(item.key, raw.is_none());
                match item.kind {
                    Kind::Bool => {
                        app.toggles.insert(item.key, raw.map(|v| v == "1").unwrap_or(false));
                    }
                    Kind::Int => {
                        app.nums.insert(item.key, raw.and_then(|v| v.parse().ok()).unwrap_or(0));
                    }
                }
            }
        }

        if let Some(mode) = vals.get("MenuMode").and_then(|v| v.parse::<usize>().ok()) {
            if (1..=5).contains(&mode) {
                app.style = mode - 1;
            }
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
        let backup = save_backup();
        let Ok(k) = key(KEY_READ | KEY_WRITE) else {
            self.status = "Не удалось открыть ключ Start11 для записи.".into();
            return;
        };
        let mut written = 0;
        if k.set_value("MenuMode", &(self.style + 1).to_string()).is_ok() {
            written += 1;
        }
        for (key, on) in &self.toggles {
            if self.missing.get(key).copied().unwrap_or(true) {
                continue;
            }
            if k.set_value(*key, if *on { "1" } else { "0" }).is_ok() {
                written += 1;
            }
        }
        for (key, value) in &self.nums {
            if self.missing.get(key).copied().unwrap_or(true) {
                continue;
            }
            if k.set_value(*key, &value.to_string()).is_ok() {
                written += 1;
            }
        }
        self.backups = list_backups();
        self.status = match backup {
            Some(path) => format!("Записано значений: {written}. Бэкап: {path}\nПерезагрузи компьютер, чтобы Start11 перечитал настройки."),
            None => format!("Записано значений: {written}. Бэкап создать не удалось."),
        };
    }

    fn cards(&mut self, ui: &mut egui::Ui) {
        ui.horizontal(|ui| {
            for (i, (name, desc)) in STYLES.iter().enumerate() {
                let (rect, resp) =
                    ui.allocate_exact_size(egui::vec2(140.0, 226.0), egui::Sense::click());
                if resp.clicked() {
                    self.style = i;
                }
                let selected = self.style == i;
                let painter = ui.painter();
                painter.rect_filled(
                    rect,
                    egui::Rounding::same(8.0),
                    if selected { CARD_HI } else { CARD },
                );
                if selected {
                    painter.rect_stroke(
                        rect,
                        egui::Rounding::same(8.0),
                        egui::Stroke::new(2.0, ACCENT),
                    );
                }

                let preview = egui::Rect::from_min_size(
                    rect.min + egui::vec2(14.0, 14.0),
                    egui::vec2(rect.width() - 28.0, 106.0),
                );
                painter.rect_filled(preview, egui::Rounding::same(4.0), egui::Color32::from_rgb(0x3a, 0x3a, 0x46));

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

    fn manage(&mut self, ui: &mut egui::Ui) {
        ui.label(egui::RichText::new("Бэкапы").color(MUTED));
        let names = self.backups.clone();
        egui::ComboBox::from_id_salt("backups")
            .width(320.0)
            .selected_text(names.get(self.selected_backup).cloned().unwrap_or_else(|| "нет бэкапов".into()))
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
            let _ = std::process::Command::new("explorer.exe").arg(backup_dir()).spawn();
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
            .frame(egui::Frame::none().fill(SIDE))
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
            .exact_height(64.0)
            .frame(egui::Frame::none().fill(BG))
            .show(ctx, |ui| {
                ui.add_space(10.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    let apply = egui::Button::new(egui::RichText::new("Применить").color(BG))
                        .fill(ACCENT)
                        .min_size(egui::vec2(160.0, 34.0));
                    if ui.add(apply).clicked() {
                        self.apply();
                    }
                    let revert = egui::Button::new(egui::RichText::new("Откатить").color(TEXT))
                        .fill(CARD)
                        .min_size(egui::vec2(160.0, 34.0));
                    if ui.add(revert).clicked() {
                        if let Some(name) = self.backups.first().cloned() {
                            let n = restore_backup(&name);
                            self.status = format!("Откат из {name}: {n} значений. Перезагрузись, чтобы применилось.");
                        } else {
                            self.status = "Бэкапов пока нет.".into();
                        }
                    }
                });
            });

        egui::CentralPanel::default()
            .frame(egui::Frame::none().fill(BG))
            .show(ctx, |ui| {
                ui.add_space(20.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    ui.label(
                        egui::RichText::new(NAV[self.section])
                            .size(24.0)
                            .strong()
                            .color(TEXT),
                    );
                });
                ui.add_space(10.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    let width = ui.available_width() - 24.0;
                    ui.allocate_ui(egui::vec2(width, ui.available_height()), |ui| {
                        match self.section {
                            0..=3 => {
                                if self.section == 0 {
                                    ui.label(egui::RichText::new("Стиль меню «Пуск»").color(MUTED));
                                    ui.add_space(6.0);
                                    self.cards(ui);
                                    ui.add_space(12.0);
                                }
                                for item in SECTIONS[self.section].items {
                                    match item.kind {
                                        Kind::Bool => {
                                            let mut on =
                                                *self.toggles.get(item.key).unwrap_or(&false);
                                            let missing =
                                                self.missing.get(item.key).copied().unwrap_or(true);
                                            let label = if missing {
                                                format!("{}  (Start11 ещё не записал это значение)", item.label)
                                            } else {
                                                item.label.to_string()
                                            };
                                            let resp = ui.add_enabled(
                                                !missing,
                                                egui::Checkbox::new(&mut on, label),
                                            );
                                            if resp.changed() {
                                                self.toggles.insert(item.key, on);
                                            }
                                        }
                                        Kind::Int => {
                                            let mut v = *self.nums.get(item.key).unwrap_or(&0);
                                            let missing =
                                                self.missing.get(item.key).copied().unwrap_or(true);
                                            ui.horizontal(|ui| {
                                                let resp = ui.add_enabled(
                                                    !missing,
                                                    egui::Slider::new(&mut v, item.min..=item.max)
                                                        .text(item.label),
                                                );
                                                if resp.changed() {
                                                    self.nums.insert(item.key, v);
                                                }
                                            });
                                        }
                                    }
                                }
                            }
                            4 => self.manage(ui),
                            _ => {
                                ui.label(egui::RichText::new("Start11 Tuner").size(16.0).color(TEXT));
                                ui.add_space(6.0);
                                ui.label(
                                    egui::RichText::new(
                                        "Конфигуратор поверх родных настроек Start11.\n\n\
                                         Ключ: HKCU\\Software\\Stardock\\Start8\\Start8.ini\\Start8\n\
                                         Значения хранятся строками, булевы — \"0\"/\"1\".\n\n\
                                         Собрано по разбору Start11 3.0.0.4.\n\
                                         Не делает: активацию и обход лицензии, редактор закреплённых, редактор цветов.",
                                    )
                                    .color(MUTED),
                                );
                            }
                        }
                    });
                });
                ui.add_space(6.0);
                ui.horizontal(|ui| {
                    ui.add_space(24.0);
                    ui.label(egui::RichText::new(&self.status).color(MUTED).size(12.0));
                });
            });
    }
}

fn main() -> eframe::Result<()> {
    if key(KEY_READ).is_err() {
        eprintln!("Start11 не найден: HKCU\\{SUBKEY}");
    }
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1040.0, 660.0])
            .with_resizable(false),
        ..Default::default()
    };
    eframe::run_native(
        "Start11 Tuner",
        options,
        Box::new(|cc| Box::new(App::new(cc))),
    )
}
