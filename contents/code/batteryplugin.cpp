#include "batteryplugin.h"
#include <QQmlExtensionPlugin>
#include <QQmlEngine>

class BatteryWattsPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")
public:
    void registerTypes(const char *uri) override {
        Q_UNUSED(uri)
        qmlRegisterType<BatteryWatts>("BatteryWatts", 1, 0, "BatteryWatts");
    }
};

#include "batteryplugin.moc"
