#!/usr/bin/env bashio
set -e

CONFIG="/etc/dnsmasq.conf"

bashio::log.info "Configuring dnsmasq..."

# Add default forward servers
for server in $(bashio::config 'dnsservers'); do
    echo "server=${server}" >> "${CONFIG}"
done

# Create domain forwards
for forward in $(bashio::config 'forwards|keys')
do
    DOMAIN=$(bashio::config "forwards[${forward}].domain")
    SERVER=$(bashio::config "forwards[${forward}].server")

    echo "server=/${DOMAIN}/${SERVER}" >> "${CONFIG}"
done

DOMAIN=$(bashio::config "domain")
echo "domain=${DOMAIN}" >> "${CONFIG}"
echo "local=/${DOMAIN}/" >> "${CONFIG}"
echo "domain-suffix=${DOMAIN}" >> "${CONFIG}"

# Create DHCP configuration
for SUBNET in $(bashio::config 'networks|keys')
do
    RANGE_START=$(bashio::config "networks[${SUBNET}].range_start")
    RANGE_END=$(bashio::config "networks[${SUBNET}].range_end")
    INTERFACE=$(bashio::config "networks[${SUBNET}].interface")
    GATEWAY=$(bashio::config "networks[${SUBNET}].gateway")
    echo "interface=${INTERFACE}" >> "${CONFIG}"
    echo "dhcp-range=${INTERFACE},${RANGE_START},${RANGE_END},7d" >> "${CONFIG}"
    echo "dhcp-option=${INTERFACE},option:router,${GATEWAY}" >> "${CONFIG}"
    echo "dhcp-option=${INTERFACE},option:domain-search,${DOMAIN}"
    for DNSSERVER in $(bashio::config "networks[${SUBNET}].dnsservers")
    do
        echo "dhcp-option=${INTERFACE},option:dns-server,${DNSSERVER}" >> "${CONFIG}"
    done 
done

# Create DHCP hosts
for host in $(bashio::config 'hosts|keys')
do
    HOST=$(bashio::config "hosts[${host}].host")
    IP=$(bashio::config "hosts[${host}].ip")
    MAC=$(bashio::config "hosts[${host}].mac")
    if [[ "${MAC}" == "null" ]]
    then
        echo "address=/${HOST}/${IP}" >> "${CONFIG}"
    else
        echo "dhcp-host=${MAC},${HOST},${IP}" >> "${CONFIG}"
    fi    
done

for host in $(bashio::config 'hostrecords|keys')
do
    HOST=$(bashio::config "hostrecords[${host}].host")
    IP=$(bashio::config "hostrecords[${host}].ip")
    echo "host-record=${HOST},${IP}" >> "${CONFIG}"
done

# Run dnsmasq
bashio::log.info "Config: \n`cat ${CONFIG}`"
bashio::log.info "Starting dnsmasq..."

exec dnsmasq -C "${CONFIG}" -z < /dev/null
