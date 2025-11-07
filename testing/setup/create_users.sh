#!/bin/bash

for user in "drwho" "martymcfly" "arthurdent" "sambeckett"; do
    useradd -m -s /bin/bash "$user"
    usermod -aG root "$user"
done

for user in "loki" "riphunter" "theflash" "tonystark" "drstrange" "bartallen"; do
    useradd -m -s /bin/bash "$user"
done
