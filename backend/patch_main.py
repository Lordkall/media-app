content = open('app/main.py', 'rb').read().decode('utf-8')

old = 'app.mount("/", StaticFiles(directory="static", html=True), name="flutter_web")'

new = '''# No-cache middleware for Flutter JS files to prevent stale browser cache
NO_CACHE_FILES = {"main.dart.js", "flutter_bootstrap.js", "flutter_service_worker.js", "index.html", "manifest.json"}

@app.middleware("http")
async def no_cache_for_js(request, call_next):
    response = await call_next(request)
    path = request.url.path.lstrip("/")
    filename = path.split("/")[-1] if path else ""
    if filename in NO_CACHE_FILES or not filename:
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response

app.mount("/", StaticFiles(directory="static", html=True), name="flutter_web")'''

if old in content:
    content = content.replace(old, new)
    open('app/main.py', 'wb').write(content.encode('utf-8'))
    print('OK - middleware no-cache agregado')
else:
    # Try with \r\n
    old2 = old.replace('\n', '\r\n')
    if old2 in content:
        content = content.replace(old2, new)
        open('app/main.py', 'wb').write(content.encode('utf-8'))
        print('OK - con CRLF')
    else:
        idx = content.find('StaticFiles(directory="static"')
        print('Posicion:', idx)
        print('Contexto:', repr(content[max(0, idx-100):idx+150]))
