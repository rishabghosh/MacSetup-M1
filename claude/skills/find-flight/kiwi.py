import json, sys, urllib.request

URL = "https://mcp.kiwi.com"
_sid = {"v": None}

def call(method, params=None, want_id=1):
    body = {"jsonrpc":"2.0","id":want_id,"method":method}
    if params is not None: body["params"] = params
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
        headers={"Content-Type":"application/json",
                 "Accept":"application/json, text/event-stream",
                 **({"Mcp-Session-Id":_sid["v"]} if _sid["v"] else {})})
    with urllib.request.urlopen(req, timeout=120) as r:
        if not _sid["v"]:
            _sid["v"] = r.headers.get("Mcp-Session-Id")
        txt = r.read().decode()
    for line in txt.splitlines():
        if line.startswith("data: "):
            return json.loads(line[6:])
    return json.loads(txt) if txt.strip().startswith("{") else {"raw": txt}

def notify(method, params=None):
    body = {"jsonrpc":"2.0","method":method}
    if params is not None: body["params"] = params
    req = urllib.request.Request(URL, data=json.dumps(body).encode(),
        headers={"Content-Type":"application/json",
                 "Accept":"application/json, text/event-stream",
                 **({"Mcp-Session-Id":_sid["v"]} if _sid["v"] else {})})
    try: urllib.request.urlopen(req, timeout=60).read()
    except Exception: pass

def connect():
    call("initialize", {"protocolVersion":"2024-11-05","capabilities":{},
                        "clientInfo":{"name":"probe","version":"1"}})
    notify("notifications/initialized")

if __name__ == "__main__":
    connect()
    if sys.argv[1] == "schema":
        t = call("tools/list")
        for tool in t["result"]["tools"]:
            print("TOOL:", tool["name"])
            print(json.dumps(tool.get("inputSchema", {}), indent=1)[:4000])
    else:
        args = json.load(open(sys.argv[1]))
        r = call("tools/call", {"name":"search-flight","arguments":args})
        print(json.dumps(r, indent=1))
