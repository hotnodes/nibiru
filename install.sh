#!/bin/bash

if [ $(id -u) != 0 ]; then
  echo "Run script from user root. Your user is ${USER}"
  exit 1
fi

### Setup variables
read -r -p "Enter your moniker: " NIBIRU_MONIKER
NIBIRU_CHAIN_ID="nibiru-itn-1"
NIBIRU_BINARY_VERSION="v0.19.2"
echo "${NIBIRU_MONIKER} " >> $HOME/.bash_profile

### Clone repo
cd $HOME && rm -rf nibiru
git clone https://github.com/NibiruChain/nibiru.git && cd nibiru
git checkout v0.19.2

### Install binaries
make build
mv build/nibid /usr/local/bin/nibid


### Update config

nibid config chain-id ${NIBIRU_CHAIN_ID}
nibid init "${NIBIRU_MONIKER}" --chain-id ${NIBIRU_CHAIN_ID}

curl -s https://rpc.itn-1.nibiru.fi/genesis | jq -r .result.genesis > $HOME/.nibid/config/genesis.json
curl -s https://snapshots2-testnet.nodejumper.io/nibiru-testnet/addrbook.json > $HOME/.nibid/config/addrbook.json

sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.nibid/config/config.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $HOME/.nibid/config/app.toml
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $HOME/.nibid/config/app.toml
sed -i 's|^pruning-interval *=.*|pruning-interval = "10"|g' $HOME/.nibid/config/app.toml
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 2000|g' $HOME/.nibid/config/app.toml

sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.001unibi\"|" $HOME/.nibid/config/app.toml

nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book

# Download latest snapshot
SNAPSHOT=$(curl -s https://snapshots2-testnet.nodejumper.io/nibiru-testnet/info.json | jq -r .fileName)
curl "https://snapshots2-testnet.nodejumper.io/nibiru-testnet/${SNAPSHOT}" | lz4 -dc - | tar -xf - -C $HOME/.nibid


### Install and run service

echo "[Unit]
Description=Nibiru Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which nibid) start
Restart=on-failure
RestartSec=3

LimitNOFILE=30000
OOMScoreAdjust=0
LimitAS=infinity
LimitCPU=infinity
LimitFSIZE=infinity
LimitAS=infinity
LimitNPROC=30000
LimitMEMLOCK=inifinity
CPUSchedulingPolicy=other
CPUSchedulingPriority=0
MemoryHigh=$(shuf -i 60-80 | head -1)%
Nice=-$(shuf -i 10-18 | head -1)
TasksMax=infinity
TasksAccounting=false

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/nibid.service

systemctl -q daemon-reload
systemctl -q enable nibid.service
systemctl -q start nibid.service


echo "##################################"
echo "Setup is finished."
echo "Wait until synchronization is finished and make create-validator transaction."
echo "##################################"
