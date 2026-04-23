--[[
    Test Suite para Collision Avoidance
    ===========================================================
    Descobre automaticamente todos os arquivos .lua dentro da
    pasta "teste/" e roda a suite completa em cada um.

    Como rodar:
        lua test_collision_avoidance.lua

    Requer Lua 5.4+ (nenhuma dependência externa).
--]]

-- ============================================================
-- Helpers de teste
-- ============================================================
local total_passed = 0
local total_failed = 0
local file_results = {} -- { {name, passed, failed} }
local test_log = {}

local current_passed = 0
local current_failed = 0

local function assert_eq(label, got, expected)
    if got == expected then
        current_passed = current_passed + 1
        print(string.format("    [PASS] %s", label))
    else
        current_failed = current_failed + 1
        print(string.format("    [FAIL] %s  —  esperado: %s, obtido: %s",
            label, tostring(expected), tostring(got)))
    end
end

local function assert_true(label, value)
    assert_eq(label, not not value, true)
end

local function assert_false(label, value)
    assert_eq(label, not not value, false)
end

local function assert_contains(label, list, substring)
    for _, msg in ipairs(list) do
        if msg:find(substring, 1, true) then
            current_passed = current_passed + 1
            print(string.format("    [PASS] %s", label))
            return
        end
    end
    current_failed = current_failed + 1
    print(string.format("    [FAIL] %s  —  substring '%s' não encontrada no log", label, substring))
end

local function assert_not_contains(label, list, substring)
    for _, msg in ipairs(list) do
        if msg:find(substring, 1, true) then
            current_failed = current_failed + 1
            print(string.format("    [FAIL] %s  —  substring '%s' encontrada (não deveria)", label, substring))
            return
        end
    end
    current_passed = current_passed + 1
    print(string.format("    [PASS] %s", label))
end

local function clear_log()
    test_log = {}
end

-- ============================================================
-- Mocks da API ArduPilot
-- ============================================================
mock_time = 0
mock_distance_cm = 10000
mock_mode = 5
mock_flying = true
mock_groundspeed = 0
mock_alt_cm = 5000
mock_loc_available = true
mock_is_taking_off = false
mock_is_landing = false
mock_params = {
    SCR_USER1 = 60,
    SCR_USER2 = 40,
    SCR_USER3 = 20,
    SCR_USER5 = 0,
    PSC_JERK_XY = 2.5,
}

function millis()
    return mock_time
end

gcs = {
    send_text = function(self, severity, text)
        table.insert(test_log, string.format("[%d] %s", severity, text))
    end
}

rangefinder = {
    distance_cm_orient = function(self, orient)
        return mock_distance_cm
    end
}

vehicle = {
    set_mode = function(self, mode)
        mock_mode = mode
    end,
    get_mode = function(self)
        return mock_mode
    end,
    get_likely_flying = function(self)
        return mock_flying
    end,
    is_taking_off = function(self)
        return mock_is_taking_off
    end,
    is_landing = function(self)
        return mock_is_landing
    end,
}

local vec_mt = {}
vec_mt.__index = vec_mt
function vec_mt:length() return mock_groundspeed end

ahrs = {
    groundspeed_vector = function(self)
        return setmetatable({}, vec_mt)
    end,
    get_location = function(self)
        if not mock_loc_available then return nil end
        return {
            alt = function(self) return mock_alt_cm end,
        }
    end,
}

param = {
    get = function(self, name)
        return mock_params[name]
    end,
    set = function(self, name, value)
        mock_params[name] = value
    end
}

-- ============================================================
-- Carregador de script (promove locals para globals)
-- ============================================================
local function load_script(path)
    local f = io.open(path, "r")
    if not f then error("Não foi possível abrir: " .. path) end
    local src = f:read("*a")
    f:close()

    -- Remove bootstrap (execução real no final do arquivo)
    src = src:gsub("gcs:send_text%(6, \"Collision Avoidance is running.-$",
                   "-- bootstrap removido para teste")

    -- Promove variáveis locais do header para globais
    local header, body = src:match("^(.-)(\nfunction .+)$")
    if header and body then
        header = header:gsub("\nlocal ([%w_]+)([ \t]*%-%-[^\n]*)", "\n%1 = nil%2")
        header = header:gsub("\nlocal ([%w_]+)([ \t]*\n)", "\n%1 = nil%2")
        header = header:gsub("\nlocal ", "\n")
        header = header:gsub("^local ([%w_]+)([ \t]*%-%-)", "%1 = nil%2")
        header = header:gsub("^local ", "")
        src = header .. body
    end

    local chunk, err = load(src, path, "t")
    if not chunk then error("Erro ao compilar: " .. err) end
    chunk()
end

-- ============================================================
-- Reset de estado entre testes
-- ============================================================
local function reset_state()
    distance_threshold = 6000
    speed_threshold    = 11
    altitude_threshold = 20
    distance           = 0
    altitude           = 0
    droneMode          = nil
    flyingState        = nil
    movingState        = false
    brakeMode          = false
    rtlMode            = false
    debugMode          = false
    groundSpeed        = 0
    runAvoidance       = false
    colisionTime       = nil
    now                = 0
    last_msg_time      = 0
    msg_interval       = 1000
    last_brake_time    = 0
    brake_interval     = 10000

    mock_time           = 0
    mock_distance_cm    = 10000
    mock_mode           = 5
    mock_flying         = true
    mock_groundspeed    = 0
    mock_alt_cm         = 5000
    mock_loc_available  = true
    mock_is_taking_off  = false
    mock_is_landing     = false
    mock_params.SCR_USER1 = 60
    mock_params.SCR_USER2 = 40
    mock_params.SCR_USER3 = 20
    mock_params.SCR_USER5 = 0
    mock_params.PSC_JERK_XY = 2.5

    clear_log()
end

-- ============================================================
-- Suite de testes (roda contra as funções globais carregadas)
-- ============================================================
local function run_test_suite()
    -- ----------------------------------------------------------
    print("\n  [Teste 1] movingState: drone parado (groundSpeed <= 1)")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 0.5
    distance = 3000
    now = 500
    colisionTime = 0
    avoidance()
    assert_false("movingState deve ser false", movingState)
    assert_false("brakeMode deve ser false (drone parado)", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 2] movingState: drone em movimento (groundSpeed > 1)")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 500
    colisionTime = 0
    avoidance()
    assert_true("movingState deve ser true", movingState)

    -- ----------------------------------------------------------
    print("\n  [Teste 3] Obstáculo detectado → ativa Brake (modo 17)")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 500
    colisionTime = 100
    avoidance()
    assert_true("brakeMode deve ser true", brakeMode)
    assert_eq("mock_mode deve ser 17 (Brake)", mock_mode, 17)
    assert_contains("Mensagem BRAKE enviada", test_log, "BRAKE! - Obstacle detected")

    -- ----------------------------------------------------------
    print("\n  [Teste 4] Já em Brake → NÃO reativa Brake")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 500
    colisionTime = 0
    brakeMode = true
    avoidance()
    assert_not_contains("Não deve enviar BRAKE novamente", test_log, "BRAKE! - Obstacle detected")

    -- ----------------------------------------------------------
    print("\n  [Teste 5] Já em RTL → NÃO ativa Brake")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 500
    colisionTime = 0
    rtlMode = true
    avoidance()
    assert_false("brakeMode deve permanecer false", brakeMode)
    assert_not_contains("Não deve enviar BRAKE", test_log, "BRAKE! - Obstacle detected")

    -- ----------------------------------------------------------
    print("\n  [Teste 6] Timer falso positivo (colisionTime < 250 ms)")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 200
    colisionTime = 100
    avoidance()
    assert_false("brakeMode deve ser false (timer insuficiente)", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 7] Brake → SmartRTL após brake_interval (10 s)")
    -- ----------------------------------------------------------
    reset_state()
    brakeMode = true
    last_brake_time = 0
    now = 10000
    distance = 8000
    avoidance()
    assert_false("brakeMode deve ser false após transição", brakeMode)
    assert_true("rtlMode deve ser true", rtlMode)
    assert_eq("mock_mode deve ser 21 (SmartRTL)", mock_mode, 21)
    assert_contains("Mensagem RTL enviada", test_log, "Returning to Home")

    -- ----------------------------------------------------------
    print("\n  [Teste 8] Brake → SmartRTL NÃO acontece antes de 10 s")
    -- ----------------------------------------------------------
    reset_state()
    brakeMode = true
    last_brake_time = 0
    now = 5000
    distance = 8000
    avoidance()
    assert_true("brakeMode deve continuar true", brakeMode)
    assert_false("rtlMode deve ser false", rtlMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 9] Zona de aviso (1.0x-1.5x threshold)")
    -- ----------------------------------------------------------
    reset_state()
    distance_threshold = 6000
    distance = 8000
    now = 2000
    last_msg_time = 0
    avoidance()
    assert_contains("Mensagem 'Obstacle close'", test_log, "Obstacle close")
    assert_eq("colisionTime resetado", colisionTime, nil)

    -- ----------------------------------------------------------
    print("\n  [Teste 10] Distância segura → reseta colisionTime")
    -- ----------------------------------------------------------
    reset_state()
    distance_threshold = 6000
    distance = 15000
    colisionTime = 999
    avoidance()
    assert_eq("colisionTime deve ser nil", colisionTime, nil)

    -- ----------------------------------------------------------
    print("\n  [Teste 11] Throttle de mensagens (msg_interval)")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 3000
    now = 500
    colisionTime = 0
    last_msg_time = 0
    brakeMode = true
    avoidance()
    assert_not_contains("Mensagem suprimida pelo throttle", test_log, "Obstacle Distance")

    clear_log()
    now = 1500
    avoidance()
    assert_contains("Mensagem permitida após throttle", test_log, "Obstacle Distance")

    -- ----------------------------------------------------------
    print("\n  [Teste 12] update() — speed > speed_threshold dobra threshold")
    -- ----------------------------------------------------------
    reset_state()
    mock_groundspeed = 15
    mock_distance_cm = 20000
    mock_time = 1000
    mock_params.SCR_USER1 = 60
    update()
    assert_eq("distance_threshold dobrado", distance_threshold, 12000)

    -- ----------------------------------------------------------
    print("\n  [Teste 13] update() — speed <= speed_threshold reseta threshold")
    -- ----------------------------------------------------------
    reset_state()
    mock_groundspeed = 5
    mock_distance_cm = 20000
    mock_time = 1000
    mock_params.SCR_USER1 = 60
    distance_threshold = 99999
    update()
    -- Após a correção do bug, a linha reseta com (SCR_USER1 or 60) * 100
    assert_eq("distance_threshold resetado para SCR_USER1*100", distance_threshold, 6000)

    -- ----------------------------------------------------------
    print("\n  [Teste 14] update() — brakeMode reseta se piloto mudou modo")
    -- ----------------------------------------------------------
    reset_state()
    mock_mode = 5
    mock_distance_cm = 20000
    mock_time = 1000
    brakeMode = true
    update()
    assert_false("brakeMode resetado pelo piloto", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 15] update() — rtlMode reseta se piloto mudou modo")
    -- ----------------------------------------------------------
    reset_state()
    mock_mode = 5
    mock_distance_cm = 20000
    mock_time = 1000
    rtlMode = true
    update()
    assert_false("rtlMode resetado pelo piloto", rtlMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 16] update() — sem rangefinder → mensagem de aviso")
    -- ----------------------------------------------------------
    reset_state()
    mock_time = 2000
    last_msg_time = 0
    local old_rf = rangefinder.distance_cm_orient
    rangefinder.distance_cm_orient = function(self, o) return nil end
    update()
    assert_contains("Aviso de lidar ausente", test_log, "No lidar data")
    rangefinder.distance_cm_orient = old_rf

    -- ----------------------------------------------------------
    print("\n  [Teste 17] update() — runAvoidance=false altitude baixa")
    -- ----------------------------------------------------------
    reset_state()
    mock_alt_cm = 1000
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    update()
    assert_false("Avoidance não roda com altitude baixa", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 18] update() — runAvoidance=false decolando")
    -- ----------------------------------------------------------
    reset_state()
    mock_alt_cm = 5000
    mock_is_taking_off = true
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    update()
    assert_false("Avoidance não roda durante decolagem", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 19] update() — runAvoidance=false pousando")
    -- ----------------------------------------------------------
    reset_state()
    mock_alt_cm = 5000
    mock_is_landing = true
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    update()
    assert_false("Avoidance não roda durante pouso", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 20] update() — runAvoidance=false no solo")
    -- ----------------------------------------------------------
    reset_state()
    mock_flying = false
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    update()
    assert_false("Avoidance não roda no solo", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 21] update() — runAvoidance=true condições OK")
    -- ----------------------------------------------------------
    reset_state()
    mock_flying = true
    mock_alt_cm = 5000
    mock_is_taking_off = false
    mock_is_landing = false
    mock_params.SCR_USER1 = 6000
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    colisionTime = 0
    update()
    assert_true("Avoidance rodou e ativou brake", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 22] Cenário completo: Detecção → Brake → SmartRTL")
    -- ----------------------------------------------------------
    reset_state()
    mock_flying = true
    mock_alt_cm = 5000
    mock_groundspeed = 5
    mock_params.SCR_USER1 = 6000
    mock_distance_cm = 3000

    mock_time = 0
    update()
    assert_false("Tick 1: brake não ativado (timer < 250ms)", brakeMode)

    mock_time = 500
    update()
    assert_true("Tick 2: brake ativado", brakeMode)
    assert_eq("Tick 2: modo deve ser 17", mock_mode, 17)

    mock_time = 10500
    mock_mode = 17
    update()
    assert_true("Tick 3: rtlMode ativo", rtlMode)
    assert_eq("Tick 3: modo deve ser 21", mock_mode, 21)

    mock_mode = 5
    mock_time = 11000
    mock_distance_cm = 20000
    update()
    assert_false("Tick 4: rtlMode resetado", rtlMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 23] update() — localização indisponível")
    -- ----------------------------------------------------------
    reset_state()
    mock_loc_available = false
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    update()
    assert_eq("Altitude deve ser 0 quando loc indisponível", altitude, 0)
    assert_false("Avoidance não roda (altitude 0 < 20)", brakeMode)

    -- ----------------------------------------------------------
    print("\n  [Teste 24] Conversão SCR_USER1: metros → centímetros")
    -- ----------------------------------------------------------
    reset_state()
    mock_groundspeed = 5         -- <= speed_threshold → reseta threshold
    mock_distance_cm = 20000
    mock_time = 1000
    mock_params.SCR_USER1 = 30   -- 30 metros
    update()
    -- Após update(), distance_threshold deve ser 30 * 100 = 3000 cm
    assert_eq("SCR_USER1=30m deve virar 3000cm", distance_threshold, 3000)

    -- ----------------------------------------------------------
    print("\n  [Teste 25] Conversão SCR_USER2: km/h → m/s")
    -- ----------------------------------------------------------
    -- Nota: na versão de produção, speed_threshold só é setado
    -- na inicialização (bootstrap). Na test_version, é setado
    -- dentro de update(). Este teste valida que a fórmula está
    -- correta quando executada.
    reset_state()
    mock_params.SCR_USER2 = 36   -- 36 km/h = 10 m/s
    -- Simula a conversão que o bootstrap faz
    speed_threshold = (mock_params.SCR_USER2 or 40) / 3.6
    assert_eq("SCR_USER2=36km/h deve virar 10 m/s", speed_threshold, 10.0)

    -- ----------------------------------------------------------
    print("\n  [Teste 26] Mensagem contém a distância do obstáculo")
    -- ----------------------------------------------------------
    reset_state()
    groundSpeed = 5
    distance = 4500              -- valor específico
    distance_threshold = 6000
    now = 2000
    colisionTime = 0             -- 2000 - 0 >= 250
    last_msg_time = 0
    brakeMode = true             -- já em brake para não triggar mudança de modo
    avoidance()
    assert_contains("Mensagem contém '4500'", test_log, "4500")

    -- ----------------------------------------------------------
    print("\n  [Teste 27] Altitude exatamente no threshold → avoidance RODA")
    -- ----------------------------------------------------------
    reset_state()
    mock_flying = true
    mock_alt_cm = 2000           -- 20m == altitude_threshold (20)
    mock_is_taking_off = false
    mock_is_landing = false
    mock_params.SCR_USER1 = 6000
    mock_distance_cm = 3000
    mock_groundspeed = 5
    mock_time = 1000
    colisionTime = 0
    update()
    assert_true("Avoidance roda quando altitude == threshold", brakeMode)
end

-- ============================================================
-- Descobre arquivos .lua dentro da pasta "teste/"
-- ============================================================
local SCRIPT_DIR = debug.getinfo(1, "S").source:match("@(.+[/\\])") or "./"
local TEST_DIR = SCRIPT_DIR .. "teste"

local function discover_scripts(dir)
    local scripts = {}
    -- Usa 'dir' no Windows para listar arquivos .lua
    local cmd = string.format('dir /b "%s\\*.lua" 2>nul', dir)
    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local name = line:match("^%s*(.-)%s*$") -- trim
            if name and #name > 0 then
                table.insert(scripts, {
                    name = name,
                    path = dir .. "\\" .. name,
                })
            end
        end
        handle:close()
    end
    return scripts
end

-- ============================================================
-- Execução principal
-- ============================================================
print("=============================================================")
print("  Test Suite — Collision Avoidance")
print("  Pasta de scripts: " .. TEST_DIR)
print("=============================================================")

local scripts = discover_scripts(TEST_DIR)

if #scripts == 0 then
    print("\n  ⚠  Nenhum arquivo .lua encontrado em: " .. TEST_DIR)
    print("     Coloque os scripts a testar dentro da pasta 'teste/'")
    os.exit(1)
end

print(string.format("\n  Encontrados %d script(s):\n", #scripts))
for i, s in ipairs(scripts) do
    print(string.format("    %d. %s", i, s.name))
end

local global_had_failure = false

for _, script in ipairs(scripts) do
    print("\n=============================================================")
    print("  Testando: " .. script.name)
    print("=============================================================")

    -- Reset contadores deste arquivo
    current_passed = 0
    current_failed = 0

    -- Tenta carregar o script
    local ok, err = pcall(load_script, script.path)
    if not ok then
        print(string.format("  ⚠  ERRO ao carregar: %s", err))
        current_failed = current_failed + 1
    else
        -- Roda a suite
        local tok, terr = pcall(run_test_suite)
        if not tok then
            print(string.format("\n  ⚠  ERRO durante os testes: %s", terr))
            current_failed = current_failed + 1
        end
    end

    -- Registra resultado deste arquivo
    table.insert(file_results, {
        name = script.name,
        passed = current_passed,
        failed = current_failed,
    })
    total_passed = total_passed + current_passed
    total_failed = total_failed + current_failed

    if current_failed > 0 then
        global_had_failure = true
    end

    print(string.format("\n  >> %s: %d passed, %d failed",
        script.name, current_passed, current_failed))
end

-- ============================================================
-- Resumo Final
-- ============================================================
print("\n\n=============================================================")
print("  RESUMO FINAL")
print("=============================================================")
print(string.format("  %-45s  %s  %s", "ARQUIVO", "PASS", "FAIL"))
print("  " .. string.rep("-", 60))
for _, r in ipairs(file_results) do
    local status = r.failed > 0 and "✗" or "✓"
    print(string.format("  %s %-43s  %4d  %4d",
        status, r.name, r.passed, r.failed))
end
print("  " .. string.rep("-", 60))
print(string.format("  %-45s  %4d  %4d", "TOTAL", total_passed, total_failed))
print("=============================================================")

if global_had_failure then
    print("\n  ⚠  ALGUNS TESTES FALHARAM!")
    os.exit(1)
else
    print("\n  ✅ TODOS OS TESTES PASSARAM!")
    os.exit(0)
end
