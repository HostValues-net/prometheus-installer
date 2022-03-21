#!/bin/bash

VERSION=v2.34.0
VERSION_PATH=prometheus-2.34.0.linux-amd64
VERSION_NODE=v1.3.1
VERSION_NODE_PATH=node_exporter-1.3.1.linux-amd64.tar

BUILD=/opt

# Setup the users and folders
sudo useradd --no-create-home --shell /bin/false prometheus
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

# Update the user groups
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Download Prometheus
rm -rf $BUILD/$VERSION_PATH
cd $BUILD
rm -rf $VERSION_PATH.tar.gz
wget https://github.com/prometheus/prometheus/releases/download/$VERSION/$VERSION_PATH.tar.gz
tar -xvf $VERSION_PATH.tar.gz
cd $VERSION_PATH

# Copy binaries and update ownership
sudo cp $BUILD/$VERSION_PATH/prometheus /usr/bin/
sudo cp $BUILD/$VERSION_PATH/promtool /usr/bin/
sudo chown prometheus:prometheus /usr/bin/prometheus
sudo chown prometheus:prometheus /usr/bin/promtool

# Copy console libraries and update ownership
sudo cp -r $BUILD/$VERSION_PATH/consoles /etc/prometheus
sudo cp -r $BUILD/$VERSION_PATH/console_libraries /etc/prometheus
sudo cp -r $BUILD/$VERSION_PATH/prometheus.yml /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml

# Install systemd service
echo "[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/prometheus.service

# Enable systemd service
sudo systemctl daemon-reload
sudo systemctl enable prometheus --now

# Download Node exporter
wget https://github.com/prometheus/node_exporter/releases/download/$VERSION_NODE/$VERSION_NODE_PATH.tar.gz
sudo tar xvzf $VERSION_NODE_PATH.tar.gz
cd $VERSION_NODE_PATH
sudo cp node_exporter /usr/bin

# Create Node exporter systemd service
echo "[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/bin/node_exporter \
— collector.mountstats \
— collector.logind \
— collector.processes \
— collector.ntp \
— collector.systemd \
— collector.tcpstat \
— collector.wifi
Restart=always
RestartSec=10s
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/node_exporter.service

# Enable systemd service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter --now

# Edit prometheus config
sed -i -e 's/\["localhost:9090"\]/\["localhost:9090", "localhost:9100"\]/g' prometheus.yml
sudo systemctl restart prometheus

# Confirm
echo -e "----------------------------"
echo -e "Installation of Prometheus with Node Exporter done!"
echo -e "It should be accessible from $HOSTNAME:9090"
echo -e "Please check your firewall settings if it's not available!"
echo -e "----------------------------"
