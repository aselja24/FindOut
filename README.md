# Приложение для изучения языков

**Разработчики:** Асель & Рухсари  
**Стек:** Flutter + Dart + Supabase 

---

##  Быстрый старт

### 1. Установка зависимостей
```bash
flutter pub get
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
├── presentation/
│   ├── screens/        # Все экраны
│   │   ├── auth/       # Splash, Onboarding, Login, Register, Setup, LevelTest
│   │   ├── home/       # Dashboard + Bottom Nav
│   │   ├── learn/      # Карточки, Словарь, Грамматика, Игры
│   │   ├── culture/    # Культура и история
│   │   ├── progress/   # Статистика 
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
- Прогресс + Ачивки
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


