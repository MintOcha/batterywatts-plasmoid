#pragma once
#include <QObject>
#include <QTimer>
#include <QFile>
#include <QtGlobal>

class BatteryWatts : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY dataChanged)
    Q_PROPERTY(double watts READ watts NOTIFY dataChanged)
    Q_PROPERTY(QString displayText READ displayText NOTIFY dataChanged)
    Q_PROPERTY(QString batteryPath READ batteryPath CONSTANT)
    Q_PROPERTY(int pollingInterval READ pollingInterval WRITE setPollingInterval NOTIFY pollingIntervalChanged)

public:
    explicit BatteryWatts(QObject *parent = nullptr) : QObject(parent), m_watts(0.0) {
        discoverBattery();
        m_timer.setInterval(2000);
        m_timer.start();
        connect(&m_timer, &QTimer::timeout, this, &BatteryWatts::update);
        update();
    }

    QString status() const { return m_status; }
    double watts() const { return m_watts; }
    QString displayText() const { return m_displayText; }
    QString batteryPath() const { return m_batteryPath; }
    int pollingInterval() const { return m_timer.interval(); }

    void setPollingInterval(int interval) {
        int boundedInterval = qBound(500, interval, 60000);
        if (m_timer.interval() == boundedInterval)
            return;

        m_timer.setInterval(boundedInterval);
        emit pollingIntervalChanged();
    }

    Q_INVOKABLE void refresh() {
        update();
    }

signals:
    void dataChanged();
    void pollingIntervalChanged();

private:
    void discoverBattery() {
        QStringList candidates = {"BAT0", "BAT1", "BAT2", "BATT", "BATTERY"};
        for (const auto &name : candidates) {
            QString path = "/sys/class/power_supply/" + name + "/type";
            QFile f(path);
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QByteArray type = f.readLine().trimmed();
                f.close();
                if (type == "Battery") {
                    m_batteryPath = "/sys/class/power_supply/" + name;
                    return;
                }
            }
        }
    }

    void update() {
        if (m_batteryPath.isEmpty()) {
            m_displayText = "? W";
            emit dataChanged();
            return;
        }

        QFile sf(m_batteryPath + "/status");
        if (sf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            m_status = QString::fromUtf8(sf.readLine().trimmed());
            sf.close();
        }

        QFile pf(m_batteryPath + "/power_now");
        if (pf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool ok;
            double raw = pf.readLine().trimmed().toDouble(&ok);
            pf.close();
            if (ok) {
                m_watts = raw / 1000000.0;
                if (m_status == "Charging")
                    m_displayText = QString("\u26A1 +%1 W").arg(m_watts, 0, 'f', 1);
                else if (m_status == "Discharging")
                    m_displayText = QString("\U0001F50B -%1 W").arg(m_watts, 0, 'f', 1);
                else if (m_status == "Full")
                    m_displayText = "\u2713 0.0 W";
                else
                    m_displayText = QString("%1 W").arg(m_watts, 0, 'f', 1);
            } else {
                m_displayText = "? W";
            }
        } else {
            m_displayText = "? W";
        }
        emit dataChanged();
    }

    QTimer m_timer;
    QString m_batteryPath;
    QString m_status;
    double m_watts;
    QString m_displayText;
};
