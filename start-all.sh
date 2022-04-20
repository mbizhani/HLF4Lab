#!/bin/bash

./start-ca-servers.sh
sleep 2
./start-network.sh
sleep 2
./start-ext-cc.sh