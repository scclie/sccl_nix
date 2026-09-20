{ serverIp ? "192.168.0.10" }:
# zone pierdol.ing - technical/public domain

{
  records = [
    { name = "@"; type = "SOA"; content = "ns1.pierdol.ing. hostmaster.pierdol.ing. 2026091601 3600 900 604800 300"; }
    { name = "@"; type = "NS"; content = "ns1.pierdol.ing."; }
    { name = "@"; type = "A"; content = serverIp; }
    { name = "ns1"; type = "A"; content = serverIp; }
    { name = "id"; type = "A"; content = serverIp; }
    { name = "chat"; type = "A"; content = serverIp; }
    { name = "discord-bridge"; type = "A"; content = serverIp; }
    { name = "livekit"; type = "A"; content = serverIp; }
    { name = "call"; type = "A"; content = serverIp; }
    { name = "mirror"; type = "A"; content = serverIp; }
    { name = "comments"; type = "A"; content = serverIp; }
  ];

  cfRecords = [
    { name = "@"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "id"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "chat"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "discord-bridge"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "livekit"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "call"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "mirror"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "comments"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
  ];
}
