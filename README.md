# Приложение для изучения языков

**Разработчики:** Асель & Рухсари  
**Стек:** Flutter + Dart + Supabase + Hive

---

##  Быстрый старт

### 1. Установка зависимостей
```bash
flutter pub get
```

### 2. Настройка Supabase
Открой `lib/core/constants/app_constants.dart` и замени:
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```
На реальные значения из Supabase Dashboard → Settings → API.

### 3. Запуск
```bash
   flutter run
```

---

## Архитектура проекта

```
lib/
├── core/
│   ├── constants/      # Константы, роуты
│   ├── router/         # GoRouter навигация
│   └── theme/          # Цвета, шрифты, темы
├── domain/
│   └── entities/       # Модели данных
├── data/               # Репозитории, datasources
├── presentation/
│   ├── screens/        # Все экраны
│   │   ├── auth/       # Splash, Onboarding, Login, Register, Setup, LevelTest
│   │   ├── home/       # Dashboard + Bottom Nav
│   │   ├── learn/      # Карточки, Словарь, Грамматика, Игры
│   │   ├── culture/    # Культура и история
│   │   ├── progress/   # Статистика и ачивки
│   │   ├── community/  # Сообщество
│   │   └── profile/    # Профиль и настройки
│   ├── blocs/          # BLoC state management
│   └── widgets/        # Переиспользуемые виджеты
└── main.dart
```

---

## База данных (Supabase PostgreSQL)

### Таблицы
| Таблица | Назначение |
|---|---|
| `profiles` | Профили пользователей |
| `decks` | Наборы карточек |
| `flashcards` | Карточки слов |
| `words` | Словарь |
| `grammar_topics` | Темы грамматики |
| `culture_articles` | Статьи культуры |
| `phrases` | Разговорник |
| `posts` | Посты сообщества |
| `achievements` | Ачивки |
| `user_progress` | Прогресс пользователя |

### Storage Buckets
- `avatars/` — фото профиля
- `app-content/` — контент приложения
- `user-cards/` — фото карточек пользователей

---

##  Дизайн

**Цвета:**
- Primary: `#6B21E8` (фиолетовый)
- Secondary: `#1DB87A` (зелёный)
- Accent: `#FF8C42` (оранжевый)

**Шрифт:** Poppins (Regular, Medium, Bold)

**Поддержка:** Светлая и тёмная тема

---

### Экраны (32 файла)

### Авторизация (7 экранов)
- Splash Screen
- Onboarding (3 слайда)
- Выбор языка
- Регистрация / Вход
- Настройка профиля (5 шагов)
- Тест уровня

### Основное приложение
- Dashboard (главная)
- Карточки + создание
- Словарь
- Грамматика
- Мини-игры (3 игры)
- Культура (5 вкладок)
- Прогресс + Ачивки
- Сообщество + Чат + Лидеры
- Профиль + Настройки

---

## Зависимости

| Пакет | Назначение |
|---|---|
| `supabase_flutter` | База данных + Auth + Storage |
| `flutter_bloc` | State management |
| `go_router` | Навигация |
| `hive_flutter` | Офлайн хранилище |
| `flutter_tts` | Озвучка слов |
| `smooth_page_indicator` | Онбординг |
| `cached_network_image` | Кэш картинок |
| `image_picker` | Выбор фото |

---


