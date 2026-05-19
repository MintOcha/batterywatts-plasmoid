TEMPLATE = lib
CONFIG += plugin qt no_install_qmltypes
QT += qml

TARGET = batteryplugin
QML_IMPORT_NAME = BatteryWatts
QML_IMPORT_MAJOR_VERSION = 1

HEADERS += batteryplugin.h
SOURCES += batteryplugin.cpp

CONFIG += install_skip
DESTDIR = $$PWD

unix {
    QMAKE_RPATHDIR += $$PWD
}
