#!/bin/bash

# Скрипт сборки и публикации релизов

# * Скрипт должен быть запущен на чистом (без изменений) репозитории (на любой ветке).
# * Релиз собирается из основной ветки проекта: develop/master (задается в переменной окружения BRANCH).
# * Все фича-ветки должны быть предварительно вмерджены в основную ветку.
# * Скрипт использует semver, поэтому в проекте должне быть выполнен `npm i semver --save-dev`
# * Докер-репозиторий указывается в переменной окружения DOCKER_REPO
# * Скрипт сборки проекта указывается в переменной окружения BUILD
# * Дополнительные параметры докера для сборки можно указать в переменной окружения DOCKER_OPTIONS

# Использование:
#   В package.json добавляется основной скрипт:
#     "release": "DOCKER_REPO=repo BUILD='npm run build-prod' BRANCH=master ./release/release.sh"
#   Так же добавляются вспомогательные скрипты для сборки разных релизов:
#     "release-major": "npm run release -- major"
#     "release-minor": "npm run release -- minor"
#     "release-patch": "npm run release -- patch"
#   Пример вызова:
#     npm run release-minor
#     npm run release-minor push // только фаза push

set -e


COLOR_ERROR='\033[1;31m'
COLOR_WARNING='\033[1;33m'
COLOR_VARIABLE='\033[1;34m'
COLOR_VALUE='\033[0;32m'

COLOR_CLEAR='\033[0m'


function checkDockerRepo {
  if [[ -z "$DOCKER_REPO" ]]; then
    echo -e "${COLOR_ERROR}Error${COLOR_CLEAR}: env variable ${COLOR_VARIABLE}DOCKER_REPO${COLOR_CLEAR} is not defined" 1>&2
    exit 1
  else
    echo -e "Using docker repository: ${COLOR_VALUE}$DOCKER_REPO${COLOR_CLEAR}"
  fi
}

function checkSourceBranch {
  if [[ -z "$BRANCH" ]]; then
    echo -e "${COLOR_WARNING}Warning${COLOR_CLEAR}: env variable ${COLOR_VARIABLE}BRANCH${COLOR_CLEAR} is not defined. Using default value: ${COLOR_VALUE}master${COLOR_CLEAR}" 1>&2
    SOURCE_BRANCH="master"
  else
    SOURCE_BRANCH=$BRANCH
  fi
}

function checkBuildCommand {
  if [[ -z "$BUILD" ]]; then
    echo -e "${COLOR_ERROR}Error${COLOR_CLEAR}: env variable ${COLOR_VARIABLE}BUILD${COLOR_CLEAR} is not defined" 1>&2
    exit 1
  else
    echo -e "Using build command: ${COLOR_VALUE}$BUILD${COLOR_CLEAR}"
    BUILD_COMMAND=$BUILD
  fi
}

function checkUncommitedChanges {
  set +e
  git diff-index --ignore-submodules --quiet HEAD --
  if [[ $? -ne 0 ]]; then
    echo -e "${COLOR_ERROR}Error${COLOR_CLEAR}: there are uncommited changes in repository" 1>&2
    exit 1
  fi
  set -e
}

function runChecks {
  # Проверяем, указан ли docker-репозиторий
  checkDockerRepo

  # Проверяем, указана ли команда сборки проекта
  checkBuildCommand

  # Проверяем, указана ли ветка, из которой собирается релиз
  checkSourceBranch

  # Проверяем, нет ли незакоммиченных изменений
  checkUncommitedChanges
}



function prepare {
  echo -e "${COLOR_VALUE}[1]${COLOR_CLEAR}: Preparing..."

  git fetch --all
  git checkout $SOURCE_BRANCH
  git pull

  echo -e "${COLOR_VALUE}[1]${COLOR_CLEAR}: Prepare: ${COLOR_VALUE}OK${COLOR_CLEAR}"
}


function build {
  echo -e "${COLOR_VALUE}[2]${COLOR_CLEAR}: Building project..."

  # if [ ! -z "$BUILD_COMMAND" ]; then
  $BUILD_COMMAND
  # fi

  echo -e "${COLOR_VALUE}[2]${COLOR_CLEAR}: Build: ${COLOR_VALUE}OK${COLOR_CLEAR}"
}


function tag {
  echo -e "${COLOR_VALUE}[3]${COLOR_CLEAR}: Tagging..."

  # Обновляем версию пакета (бег гит-тега, он создастся ниже)
  npm version $VERSION --no-git-tag-version
  git add package.json package-lock.json

  git commit -m "Bump version: $CURRENT_VERSION -> $VERSION"
  git tag $VERSION

  # Пушим девелоп/мастер, тэг
  git push origin $SOURCE_BRANCH
  git push origin $VERSION

  echo -e "${COLOR_VALUE}[3]${COLOR_CLEAR}: Tagging: ${COLOR_VALUE}OK${COLOR_CLEAR}"
}


function push {
  echo -e "${COLOR_VALUE}[4]${COLOR_CLEAR}: Docker: building and pushing image..."

  docker build ${DOCKER_OPTIONS} . --tag $DOCKER_REPO:latest --tag $DOCKER_REPO:$VERSION
  docker push $DOCKER_REPO:latest
  docker push $DOCKER_REPO:$VERSION

  echo -e "${COLOR_VALUE}[4]${COLOR_CLEAR}: Docker: ${COLOR_VALUE}OK${COLOR_CLEAR}"
}

function release {
  echo ""
  echo -e "Starting release: ${COLOR_VARIABLE}$LEVEL${COLOR_CLEAR} (${COLOR_VALUE}$CURRENT_VERSION${COLOR_CLEAR} -> ${COLOR_VALUE}$VERSION${COLOR_CLEAR})"
  echo ""

  # Переключаемся на основную ветку
  prepare

  echo ""

  # Собираем проект
  build

  echo ""

  # Поднимаем версию, пушим в гит
  tag

  echo ""

  # Собираем и выкладываем image
  push

  echo ""
  echo -e "Release ${COLOR_VARIABLE}$LEVEL${COLOR_CLEAR} (${COLOR_VALUE}$CURRENT_VERSION${COLOR_CLEAR} -> ${COLOR_VALUE}$VERSION${COLOR_CLEAR}) finished"
  echo ""
}

function usage {
  echo "Usage:"
  echo "  DOCKER_REPO=... BUILD=... [BRANCH=...] release.sh [major | minor | patch] [prepare | build | tag | push]"
}


if [[ $1 == "major" ]] || [[ $1 == "minor" ]] || [[ $1 == "patch" ]]; then

  # Предварительные проверки
  runChecks


  # Поднимаемая версия: major | minor | patch
  LEVEL=$1

  CURRENT_VERSION=`node -p "require('./package.json').version"`
  VERSION=`npx semver -i $LEVEL $CURRENT_VERSION`


  if [[ -z "$2" ]]; then
    release
  elif [[ $2 == "prepare" ]]; then
    prepare
  elif [[ $2 == "build" ]]; then
    build
  elif [[ $2 == "tag" ]]; then
    tag
  elif [[ $2 == "push" ]]; then
    VERSION=$CURRENT_VERSION
    push
  else
    usage
    exit 1
  fi

else
  usage
  exit 1
fi

