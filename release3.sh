#!/bin/bash

# Скрипт для выполнения релиза новой версии проекта
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Функция для извлечения версии из gradle.properties
get_current_version() {
    if [ ! -f "gradle.properties" ]; then
        log_error "Файл gradle.properties не найден"
        exit 1
    fi
    
    local version=$(grep -E "^project_version=" gradle.properties | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    if [ -z "$version" ]; then
        log_error "Не удалось найти project_version в gradle.properties"
        exit 1
    fi
    
    echo "$version"
}

# Функция для запроса версии у пользователя
get_release_version() {
    local default_version=$1
    local release_version
    
    echo ""
    echo -e "${GREEN}Текущая версия в gradle.properties: ${default_version}${NC}"
    read -p "Введите версию для релиза [по умолчанию: ${default_version}]: " release_version
    
    # Если пользователь не ввел версию, используем дефолтную
    if [ -z "$release_version" ]; then
        release_version="$default_version"
        echo -e "${GREEN}Используется версия по умолчанию: ${release_version}${NC}"
    fi
    
    # Проверяем формат версии (должна быть в формате X.Y.Z)
    if ! echo "$release_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_error "Неверный формат версии. Должен быть в формате X.Y.Z (например: 1.8.1)"
        exit 1
    fi
    
    echo "$release_version"
}

# Функция для инкремента версии по правилам: увеличиваем последнюю цифру до 9, 
# затем увеличиваем предпоследнюю и сбрасываем последнюю в 0
increment_version() {
    local version=$1
    local major=$(echo $version | cut -d'.' -f1)
    local minor=$(echo $version | cut -d'.' -f2)
    local patch=$(echo $version | cut -d'.' -f3)
    
    # Увеличиваем patch версию
    if [ "$patch" -lt 9 ]; then
        # Если patch меньше 9, просто увеличиваем его
        patch=$((patch + 1))
    else
        # Если patch равен 9, увеличиваем minor и сбрасываем patch в 0
        minor=$((minor + 1))
        patch=0
    fi
    
    echo "${major}.${minor}.${patch}"
}

# Функция для обновления версий с префиксом smartix_ в gradle.properties
update_smartix_versions() {
    local old_version=$1
    local new_version=$2
    
    log_info "Поиск версий с префиксом smartix_ для обновления..."
    
    # Обновляем все версии с префиксом smartix_ в gradle.properties
    if grep -q "smartix_.*_version=" gradle.properties; then
        log_info "Обновление версий smartix_ в gradle.properties"
        
        # Получаем список всех smartix версий
        smartix_versions=$(grep "smartix_.*_version=" gradle.properties | cut -d'=' -f1)
        
        for smartix_var in $smartix_versions; do
            # Для каждой smartix переменной применяем тот же алгоритм инкремента
            current_smartix_version=$(grep "^${smartix_var}=" gradle.properties | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
            
            if [ "$current_smartix_version" = "$old_version" ]; then
                log_info "Обновление $smartix_var: $old_version → $new_version"
                sed -i "s/^${smartix_var}=${old_version}$/${smartix_var}=${new_version}/" gradle.properties
            else
                log_warning "Версия $smartix_var ($current_smartix_version) не совпадает с project_version ($old_version), оставляем без изменений"
            fi
        done
        
        # Проверяем, что изменения применились
        updated_count=$(grep -c "smartix_.*_version=${new_version}" gradle.properties || true)
        log_info "Обновлено ${updated_count} версий с префиксом smartix_"
    else
        log_warning "Версии с префиксом smartix_ не найдены в gradle.properties"
    fi
}

# Функция для проверки наличия несохраненных изменений
check_clean_working_tree() {
    if ! git diff --exit-code --quiet || ! git diff --cached --exit-code --quiet; then
        log_error "Есть несохраненные изменения. Пожалуйста, закоммитьте или отмените их перед запуском релиза."
        git status
        exit 1
    fi
}

# Функция для проверки существования веток
check_branch_exists() {
    local branch=$1
    if ! git show-ref --verify --quiet "refs/heads/$branch"; then
        log_error "Ветка $branch не существует"
        exit 1
    fi
}

# Основной скрипт
log_step "Начало процесса релиза"

# Проверяем, что мы в git репозитории
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Это не git репозиторий"
    exit 1
fi

# Проверяем наличие несохраненных изменений
check_clean_working_tree

# Проверяем существование веток
check_branch_exists "main"
check_branch_exists "develop"

# Получаем текущую версию из gradle.properties
CURRENT_VERSION=$(get_current_version)
log_info "Текущая версия в проекте: $CURRENT_VERSION"

# Запрашиваем версию для релиза у пользователя
RELEASE_VERSION=$(get_release_version "$CURRENT_VERSION")

# Подтверждение действия
echo ""
echo -e "${YELLOW}Будет выполнено:${NC}"
echo "- Мердж develop в main"
echo "- Создание ветки release/${RELEASE_VERSION}"
echo "- Обновление версии в develop до $(increment_version "$RELEASE_VERSION")"
echo ""
read -p "Продолжить? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log_info "Отмена выполнения скрипта"
    exit 0
fi

# Шаг 1: Работа с main веткой
log_step "1. Работа с main веткой"
log_info "Переключение на main и обновление"
git checkout main
git pull origin main

log_info "Мердж develop в main"
if ! git merge origin/develop -m "Merge develop into main for release"; then
    log_error "Конфликт при мердже develop в main. Разрешите конфликты и запустите скрипт снова."
    exit 1
fi

log_info "Пуш изменений в origin main"
git push origin main

# Шаг 2: Создание release ветки
log_step "2. Создание release ветки"
log_info "Переключение на develop"
git checkout develop
git pull origin develop

# Обновляем project_version до релизной версии
log_info "Обновление project_version до релизной версии: $RELEASE_VERSION"
sed -i "s/^project_version=${CURRENT_VERSION}$/project_version=${RELEASE_VERSION}/" gradle.properties

# Коммитим изменения с релизной версией
git add gradle.properties
git commit -m "prepare release $RELEASE_VERSION" || log_info "Нет изменений для коммита"

RELEASE_BRANCH="release/${RELEASE_VERSION}"
log_info "Создание release ветки: $RELEASE_BRANCH"

git checkout -b "$RELEASE_BRANCH"
log_info "Пуш release ветки в origin"
git push --set-upstream origin "$RELEASE_BRANCH"

# Шаг 3: Обновление версии в develop
log_step "3. Обновление версии в develop"
log_info "Переключение обратно на develop"
git checkout develop

# Инкремент версии для следующей разработки
NEW_VERSION=$(increment_version "$RELEASE_VERSION")
log_info "Новая версия для разработки: $RELEASE_VERSION → $NEW_VERSION"

# Обновляем project_version в gradle.properties
log_info "Обновление project_version в gradle.properties"
sed -i "s/^project_version=${RELEASE_VERSION}$/project_version=${NEW_VERSION}/" gradle.properties

# Обновляем версии с префиксом smartix_ в gradle.properties
update_smartix_versions "$RELEASE_VERSION" "$NEW_VERSION"

# Проверяем изменения
log_info "Проверка изменений в gradle.properties:"
git diff gradle.properties || true

# Коммит изменений
log_info "Создание коммита с новой версией"
git add gradle.properties
git commit -m "start ${NEW_VERSION}"

log_info "Пуш изменений в origin develop"
git push origin develop

log_step "Процесс релиза завершен успешно"
echo "Релизная версия: $RELEASE_VERSION (ветка $RELEASE_BRANCH)"
echo "Следующая версия для разработки: $NEW_VERSION"
log_info "Не забудьте протестировать и завершить релиз в ветке $RELEASE_BRANCH"