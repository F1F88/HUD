#include <sdktools>
#include <sdkhooks>

#undef   REQUIRE_EXTENSIONS
#include <clientprefs>
#define  REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#undef  MAXPLAYERS
#define MAXPLAYERS                          9

#define MAX_KEY_HINT_TEXT_LEN               255
#define MAX_CLASSNAME                       32

#define PLUGIN_NAME                         "HUD"
#define PLUGIN_VERSION                      "v1.2.7"
#define PLUGIN_DESCRIPTION                  "Show data in HUD (KeyHintText)"
#define PREFIX_CV                           "sm_hud"
#define PREFIX_MESSAGE                      "[HUD] By F1F88"
#define PREFIX_PHRASES_FILE                 PLUGIN_NAME

#define BIT_SHOW_ENABLED                    ( 1 << 0 )
#define BIT_SHOW_AT_DEATH                   ( 1 << 1 )
#define BIT_SHOW_SELF_NAME                  ( 1 << 2 )
#define BIT_SHOW_SELF_HEALTH                ( 1 << 3 )
#define BIT_SHOW_SELF_STAMINA               ( 1 << 4 )
#define BIT_SHOW_SELF_SPEED                 ( 1 << 5 )
#define BIT_SHOW_SELF_SPEED_VERTICAL        ( 1 << 6 )
#define BIT_SHOW_SELF_CLIP                  ( 1 << 7 )
#define BIT_SHOW_SELF_INVENTORY             ( 1 << 8 )
#define BIT_SHOW_SELF_STATUS                ( 1 << 9 )
#define BIT_SHOW_AIM                        ( 1 << 10 )
#define BIT_SHOW_AIM_PLAYER                 ( 1 << 11 )
#define BIT_SHOW_AIM_PLAYER_NAME            ( 1 << 12 )
#define BIT_SHOW_AIM_ZOMBIE                 ( 1 << 13 )
#define BIT_SHOW_AIM_AMMO                   ( 1 << 14 )
#define BIT_SHOW_AIM_ITEM                   ( 1 << 15 )
#define BIT_SHOW_DIVIDER                    ( 1 << 16 )
#define BIT_DEFAULT                         ( 1 << 17 ) - 1 - BIT_SHOW_SELF_NAME - BIT_SHOW_SELF_SPEED - BIT_SHOW_SELF_SPEED_VERTICAL

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/"
};

enum
{
    OBS_MODE_IN_EYE = 4,    // First Person
    OBS_MODE_CHASE,         // Third Person
    OBS_MODE_POI,           // Third Person but no player name and health ?
    OBS_MODE_FREE,          // Free
}

enum
{
    O_AMMO_9MM = 1,     // 1
    O_AMMO_45ACP,       // 2
    O_AMMO_357,         // 3
    O_AMMO_12Gauge,     // 4
    O_AMMO_22LR,        // 5
    O_AMMO_308,         // 6
    O_AMMO_556,         // 7
    O_AMMO_762,         // 8
    O_AMMO_Grenade,     // 9    | weight: 100
    O_AMMO_Molotov,     // 10   | weight: 100
    O_AMMO_TNT,         // 11   | weight: 100
    O_AMMO_ARROW,       // 12
    O_AMMO_Fuel,        // 13
    O_AMMO_Boards,      // 14
    O_AMMO_Flares,      // 15

    O_AMMO_Total
}

enum
{
    O_Bleed,            // 是否流血
    O_InfectedStart,    // 感染开始时间
    O_InfectedEnd,      // 感染结束时间
    O_VACCINATED,       // 注射疫苗
    O_BlindnessEnd,     // 疫苗部分失明影响结束时间
    O_Stamina,          // 体力
    O_vecVelocity0,     // 移动速度
    O_IsCharging,       // 是否在蓄力
    O_ActiveWeapon,     // 当前武器
    O_Ammo,             // 弹药库
    O_CarriedWeight,    // 一号背包重量
    O_ObserverMode,     // 观察模式
    O_ObserverTarget,   // 观察的目标
    O_Type,             // 武器的弹药类型
    O_Clip,             // 武器弹夹剩余子弹数

    O_Total
};

int         g_offset[O_Total];              // 记录偏移量

// bool        g_plugin_late
bool        cv_plugin_enabled
            , cv_always_show_status
            , cv_always_show_target
            , cv_trace_hull;

int         cv_inv_maxcarry
            , cv_inv_ammoweight;

float       cv_update_interval
            , cv_target_range
            , cv_trace_width;

float       g_hullMins[3], g_hullMaxs[3];

Handle      g_timer;
Cookie      g_cookie;

int         g_client_cookie[MAXPLAYERS + 1] = {BIT_DEFAULT, ...};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // g_plugin_late = late;
    if( (g_offset[O_Bleed]          = FindSendPropInfo("CNMRiH_Player", "_bleedingOut")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::_bleedingOut'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_InfectedStart]  = FindSendPropInfo("CNMRiH_Player", "m_flInfectionTime")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_flInfectionTime'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_VACCINATED]     = FindSendPropInfo("CNMRiH_Player", "_vaccinated")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::_vaccinated'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_InfectedEnd]    = FindSendPropInfo("CNMRiH_Player", "m_flInfectionDeathTime")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_flInfectionDeathTime'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_BlindnessEnd]   = FindSendPropInfo("CNMRiH_Player", "m_flPartialBlindnessEffectEnd")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_flPartialBlindnessEffectEnd'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_Stamina]        = FindSendPropInfo("CNMRiH_Player", "m_flStamina")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_flStamina'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_vecVelocity0]   = FindSendPropInfo("CNMRiH_Player", "m_vecVelocity[0]")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_vecVelocity[0]'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_ActiveWeapon]   = FindSendPropInfo("CNMRiH_Player", "m_hActiveWeapon")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_hActiveWeapon'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_Ammo]           = FindSendPropInfo("CNMRiH_Player", "m_iAmmo")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_iAmmo'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_CarriedWeight]  = FindSendPropInfo("CNMRiH_Player", "_carriedWeight")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::_carriedWeight'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_ObserverMode]   = FindSendPropInfo("CNMRiH_Player", "m_iObserverMode")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_iObserverMode'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_ObserverTarget] = FindSendPropInfo("CNMRiH_Player", "m_hObserverTarget")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_Player::m_hObserverTarget'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_Type]           = FindSendPropInfo("CNMRiH_WeaponBase", "m_iPrimaryAmmoType")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_WeaponBase::m_iPrimaryAmmoType'!");
        return APLRes_Failure;
    }
    if( (g_offset[O_Clip]           = FindSendPropInfo("CNMRiH_WeaponBase", "m_iClip1")) < 1 )
    {
        strcopy(error, err_max,     "Can't find offset 'CNMRiH_WeaponBase::m_iClip1'!");
        return APLRes_Failure;
    }

    MarkNativeAsOptional("Cookie.Cookie");
    MarkNativeAsOptional("Cookie.Get");
    MarkNativeAsOptional("Cookie.GetInt");
    MarkNativeAsOptional("Cookie.Set");
    MarkNativeAsOptional("Cookie.SetInt");
    MarkNativeAsOptional("SetCookieMenuItem");
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations(PREFIX_PHRASES_FILE...".phrases");

    CreateConVar(PREFIX_CV..."_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY | FCVAR_DONTRECORD);
    ConVar convar;
    (convar = CreateConVar(PREFIX_CV..."_enabled",              "1",        "是否启用插件", _, true, 0.0, true, 1.0)).AddChangeHook(On_ConVar_Change);
    cv_plugin_enabled = convar.BoolValue;
    (convar = CreateConVar(PREFIX_CV..."_always_show_status",   "0",        "0 = 没有特殊状态时不显示状态行. 1 = 即使没有特殊状态也显示状态行", _, true, 0.0, true, 1.0)).AddChangeHook(On_ConVar_Change);
    cv_always_show_status = convar.BoolValue;
    (convar = CreateConVar(PREFIX_CV..."_always_show_target",   "0",        "0 = 目标没有匹配的名称时不显示目标名称行. 1 = 即使目标没有匹配的名称也显示目标名称行", _, true, 0.0, true, 1.0)).AddChangeHook(On_ConVar_Change);
    cv_always_show_target = convar.BoolValue;
    (convar = CreateConVar(PREFIX_CV..."_update_interval",      "0.20",     "越小刷新越快, 性能消耗越大, 占用的网络带宽也越多。单位-秒", _, true, 0.01)).AddChangeHook(On_ConVar_Change);
    cv_update_interval = convar.FloatValue;
    (convar = CreateConVar(PREFIX_CV..."_trace_range",          "1024.0",   "The maximum reach of the player target trace in game units", _, true, 32.0)).AddChangeHook(On_ConVar_Change);
    cv_target_range = convar.FloatValue;
    (convar = CreateConVar(PREFIX_CV..."_trace_hull",           "0",        "如果 trace ray 没有获取到目标, 使用 trace hull 再次尝试", _, true, 0.0, true, 1.0)).AddChangeHook(On_ConVar_Change);
    cv_trace_hull = convar.BoolValue;
    (convar = CreateConVar(PREFIX_CV..."_trace_width",          "16.0",     "二次搜索目标的射线的宽度", _, true, 0.1)).AddChangeHook(On_ConVar_Change);
    cv_trace_width = convar.FloatValue;
    (convar = FindConVar("inv_maxcarry")).AddChangeHook(On_ConVar_Change);
    cv_inv_maxcarry = convar.IntValue;
    (convar = FindConVar("inv_ammoweight")).AddChangeHook(On_ConVar_Change);
    cv_inv_ammoweight = convar.IntValue;

    AutoExecConfig(true, PLUGIN_NAME);

    g_cookie = new Cookie(PLUGIN_NAME..." By F1F88", PLUGIN_NAME..." client preference", CookieAccess_Private);
    SetCookieMenuItem(CustomCookieMenu, 0, "HUD");
}

public void On_ConVar_Change(ConVar convar, const char[] old_value, const char[] new_value)
{
    if ( convar == INVALID_HANDLE )
    {
        return ;
    }

    char convar_name[64];
    convar.GetName(convar_name, 64);

    if( ! strcmp(convar_name, PREFIX_CV..."_enabled") )
    {
        cv_plugin_enabled = convar.BoolValue;
        cv_plugin_enabled ? Global_Timer_On() : Global_Timer_Off();
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_always_show_status") )
    {
        cv_always_show_status = convar.BoolValue;
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_always_show_target") )
    {
        cv_always_show_target = convar.BoolValue;
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_update_interval") )
    {
        cv_update_interval = convar.FloatValue;
        Global_Timer_Off();
        Global_Timer_On();
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_trace_range") )
    {
        cv_target_range = convar.FloatValue;
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_trace_hull") )
    {
        cv_trace_hull = convar.BoolValue;
    }
    else if( ! strcmp(convar_name, PREFIX_CV..."_trace_width") )
    {
        cv_trace_width = convar.FloatValue;
        SetHullSize();
    }
    else if( ! strcmp(convar_name, "inv_maxcarry") )
    {
        cv_inv_maxcarry = convar.IntValue;
    }
    else if( ! strcmp(convar_name, "inv_ammoweight") )
    {
        cv_inv_ammoweight = convar.IntValue;
    }
}

public void OnConfigsExecuted()
{
    if( cv_plugin_enabled )
    {
        SetHullSize();
        Global_Timer_On();
    }
}

public void OnClientPutInServer(int client)
{
    g_client_cookie[client] = g_cookie.GetInt(client, BIT_DEFAULT);
}

// ========================================================================================================================================================================

Action Timer_Global(Handle timer)
{
    if( ! cv_plugin_enabled )
    {
        return Plugin_Continue;
    }

    RequestFrame(Frame_Send_All);
    return Plugin_Continue;
}

void Frame_Send_All()
{
    static int client;
    static char text[MAX_KEY_HINT_TEXT_LEN];
    // static float start, end;

    // start = GetEngineTime();
    // for(int i=0; i<=10; ++i)
    for( client=1; client<=MaxClients; ++client )
    {
        if( IsClientInGame(client) && CheckClientPerf(client, BIT_SHOW_ENABLED) )
        {
            if( IsPlayerAlive(client) )
            {
                GetHUDText(client, client, text);
                SendMessageText(client, text);
            }
            else if( CheckClientPerf(client, BIT_SHOW_AT_DEATH) )
            {
                static int observer_mode, target;
                observer_mode = GetObserverMode(client);
                if( observer_mode == OBS_MODE_IN_EYE || observer_mode == OBS_MODE_CHASE || observer_mode == OBS_MODE_POI )
                {
                    target = GetObserverTarget(client);
                    if( target != client && target > 0 && target <= MaxClients && IsClientInGame(target) )
                    {
                        GetHUDText(target, client, text);
                        SendMessageText(client, text);
                    }
                }
            }
        }
    }
    // end = GetEngineTime();
    // PrintToServer(" size=%d | %f - %f = %f ", strlen(text), end, start, end-start);
}

void GetHUDText(int client, int to_client, char[] text)
{
    text[0] = '\0';
    // strcopy(text, PREFIX_MESSAGE);
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_NAME) )
    {
        AddNewLine_Player_Name(client, client, text);       // 自己的 名称
    }
    AddText_Player(client, to_client, text);                // 自己的 数据

    if( CheckClientPerf(to_client, BIT_SHOW_AIM) )          // 瞄准的目标
    {
        static int aim_entity;
        static char classname[32];

        aim_entity = GetAimEntity(client);

        if( aim_entity <= 0 )                               // 瞄准 世界 或 无效目标
        {
            return ;
        }
        else if( aim_entity <= MaxClients )                 // 瞄准玩家
        {
            if( IsClientInGame(aim_entity) && IsPlayerAlive(aim_entity) && CheckClientPerf(to_client, BIT_SHOW_AIM_PLAYER) )
            {
                AddNewLine_Divider(to_client, text);
                if( CheckClientPerf(to_client, BIT_SHOW_AIM_PLAYER_NAME) )
                {
                    AddNewLine_Player_Name(aim_entity, to_client, text); // 目标玩家的 名称
                }
                AddText_Player(aim_entity, to_client, text);
            }
        }
        else if( GetEntityClassname(aim_entity, classname, MAX_CLASSNAME) )
        {
            if( IsZombie(classname) )                       // 瞄准丧尸
            {
                AddText_Zombie(client, to_client, aim_entity, classname, text);
            }
            else if( ! strcmp(classname, "item_ammo_box") ) // 瞄准弹药盒
            {
                AddText_Ammo(aim_entity, to_client, text);
            }
            else                                            // 瞄准道具
            {
                AddText_Item(to_client, classname, text);
            }
        }
    }
}

// ========================================================================================================================================================================

stock void AddText_Player(int client, int to_client, char[] text)
{
    // Todo: 支持皮肤名称
    // if( CheckClientPerf(to_client, BIT_SHOW_SELF_NAME) )        // 名称
    // {
    //     AddNewLine_Player_Name(client, to_client, text);
    // }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_HEALTH) )      // 血量
    {
        AddNewLine_Player_Health(client, to_client, text);
    }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_STAMINA) )     // 体力
    {
        AddNewLine_Player_Stamina(client, to_client, text);
    }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_SPEED) )       // 速度
    {
        AddNewLine_Speed(client, to_client, text);
    }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_CLIP) )        // 子弹
    {
        AddNewLine_Player_Clip(client, to_client, text);
    }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_INVENTORY) )   // 库存负重
    {
        AddNewLine_Player_Inventory(client, to_client, text);
    }
    if( CheckClientPerf(to_client, BIT_SHOW_SELF_STATUS) )      // 状态 - 流血、感染、感染剩余、疫苗注射、疫苗近视剩余
    {
        AddNewLine_Player_Status(client, to_client, text);
    }
}

stock void AddText_Zombie(int client, int to_client, int entity, char[] classname, char[] text)
{
    if( CheckClientPerf(to_client, BIT_SHOW_AIM_ZOMBIE) )
    {
        AddNewLine_Divider(to_client, text);
        AddNewLine_Zombie_Name(to_client, classname, text);
        AddNweLine_Zombie_Health(entity, to_client, text);
    }
}

stock void AddText_Ammo(int entity, int to_client, char[] text)
{
    if( CheckClientPerf(to_client, BIT_SHOW_AIM_AMMO) )
    {
        AddNewLine_Divider(to_client, text);

        static char model[PLATFORM_MAX_PATH];
        GetEntPropString(entity, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);

        if( TranslationPhraseExists(model) )
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_ammo", to_client, model, to_client);
        }
        else
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_ammo", to_client, "phrase_ammo_default", to_client);
        }
    }
}

stock void AddText_Item(int to_client, char[] phrase_key, char[] text)
{
    if( CheckClientPerf(to_client, BIT_SHOW_AIM_ITEM) )
    {
        if( TranslationPhraseExists(phrase_key) )
        {
            AddNewLine_Divider(to_client, text);
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_item_phrase", to_client, phrase_key, to_client);
        }
        else if( cv_always_show_target )
        {
            AddNewLine_Divider(to_client, text);
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_item_string", to_client, phrase_key);
        }
    }
}

// ========================================================================================================================================================================

void AddNewLine_Player_Name(int client, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_player_name", to_client, client);
}

void AddNewLine_Player_Health(int client, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_hp", to_client, GetClientHealth(client));
}

void AddNewLine_Player_Stamina(int client, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_stamina", to_client, GetStamina(client));
}

void AddNewLine_Speed(int client, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_speed", to_client, GetSpeed(client));
}

void AddNewLine_Player_Clip(int client, int to_client, char[] text)
{
    static int weapon, ammo_clip1, ammo_clip_backpack;

    weapon = GetActiveWeapon(client);

    if( IsValidEntity(weapon) )
    {
        ammo_clip1 = GetWeapon_Clip1_Remaining(weapon);
        ammo_clip_backpack = GetWeapon_ClipBK_Remaining(client, weapon);
        if( ammo_clip1 >= 0 && ammo_clip_backpack >= 0)
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_clip", to_client, ammo_clip1, ammo_clip_backpack);
        }
    }
}

void AddNewLine_Player_Inventory(int client, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_inventory", to_client, GetCarriedWeight(client), cv_inv_maxcarry);
}

void AddNewLine_Player_Status(int client, int to_client, char[] text)
{
    static float    time_now, time_infected_end, time_blindness_end;
    static bool     is_following;

    time_now = GetGameTime();
    is_following = false;

    if( IsBleeding(client) )
    {
        Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_label", to_client, "phrase_status_bleeding", to_client);
        is_following = true;
    }

    if( IsInfected(client, time_infected_end, time_now) )
    {
        if( is_following )
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_delimiter", to_client, "phrase_status_infected", to_client, time_infected_end - time_now);
        }
        else
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_label", to_client, "phrase_status_infected", to_client, time_infected_end - time_now);
            is_following = true;
        }
    }
    else if( IsVaccinated(client) )
    {
        if( is_following )
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_delimiter", to_client, "phrase_status_vaccinated", to_client);
        }
        else
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_label", to_client, "phrase_status_vaccinated", to_client);
            is_following = true;
        }

        if( IsBlindness(client, time_blindness_end, time_now) )
        {
            Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T", text, "phrase_status_delimiter", to_client, "phrase_status_vaccine_effect", to_client, time_blindness_end - time_now);
        }
    }

    if( is_following )
    {
        StrCat(text, MAX_KEY_HINT_TEXT_LEN, "\n");
    }
    else if( cv_always_show_status )
    {
        Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T%T\n", text, "phrase_status_label", to_client, "phrase_status_none", to_client);
    }
}

void AddNewLine_Divider(int to_client, char[] text)
{
    if( CheckClientPerf(to_client, BIT_SHOW_DIVIDER) )
    {
        Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_divider", to_client);
    }
}

void AddNewLine_Zombie_Name(int to_client, char[] zombie_classname, char[] text)
{
    if( TranslationPhraseExists(zombie_classname) )
    {
        Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_zombie_name", to_client, zombie_classname, to_client);
    }
    else
    {
        Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_zombie_name", to_client, "phrase_zombie_name_default", to_client);
    }
}

void AddNweLine_Zombie_Health(int entity, int to_client, char[] text)
{
    Format(text, MAX_KEY_HINT_TEXT_LEN, "%s%T\n", text, "phrase_hp", to_client, GetEntProp(entity, Prop_Data, "m_iHealth"));
}

// ========================================================================================================================================================================

stock bool IsBleeding(int client)
{
    return GetEntData(client, g_offset[O_Bleed], 1) == 1;
}

stock bool IsInfected(int client, float &time_infected_end, float time_now=0.0)
{
    time_infected_end = GetEntDataFloat(client, g_offset[O_InfectedEnd]);
    return FloatCompare(time_infected_end, (time_now == 0.0 ? GetEngineTime() : time_now)) == 1;
    // return GetEntDataFloat(client, g_offset[O_InfectedStart]) > 0.0 && FloatCompare(GetEntDataFloat(client, g_offset[O_InfectedEnd]), GetGameTime()) == 1;
}

stock bool IsVaccinated(int client)
{
    return GetEntData(client, g_offset[O_VACCINATED]) == 1;
}

// time_infected_end 实测并不完全准确, 会稍微晚几秒才完全恢复视力
stock bool IsBlindness(int client, float &time_blindness_end, float time_now=0.0)
{
    // return RunEntVScriptBool(client, "IsPartialBlindnessActive()");
    time_blindness_end = GetEntDataFloat(client, g_offset[O_BlindnessEnd]);
    return FloatCompare(time_blindness_end, (time_now == 0.0 ? GetEngineTime() : time_now)) == 1;
}

stock bool IsZombie(char[] classname)
{
    // npc_nmrih_shamblerzombie  |  npc_nmrih_runnerzombie  |  npc_nmrih_kidzombie  |  npc_nmrih_turnedzombie
    return ! strncmp(classname, "npc_nmrih_", 10);
    // return ! strncmp(classname, "npc_nmrih_", 10) && StrContains(classname, "zombie", false) != -1;
}

stock float GetStamina(int client)
{
    return GetEntDataFloat(client, g_offset[O_Stamina]);
}

stock float GetSpeed(int client, float vel[3]={})
{
    vel[0] = GetEntDataFloat(client, g_offset[O_vecVelocity0]);
    vel[1] = GetEntDataFloat(client, g_offset[O_vecVelocity0] + 4);
    if( CheckClientPerf(client, BIT_SHOW_SELF_SPEED_VERTICAL) )
    {
        vel[2] = GetEntDataFloat(client, g_offset[O_vecVelocity0] + 8);
    }
    else
    {
        vel[2] = 0.0;
    }
    return GetVectorLength(vel);
}

stock int GetActiveWeapon(int client)
{
    return GetEntDataEnt2(client, g_offset[O_ActiveWeapon]);
}

stock int GetWeapon_Clip1_Remaining(int weapon)
{
    return GetEntData(weapon, g_offset[O_Clip]);
}

stock int GetWeapon_ClipBK_Remaining(int client, int weapon)
{
    return GetEntData(client, g_offset[O_Ammo] + GetEntData(weapon, g_offset[O_Type]) * 4);
}

stock int GetInventory1CarriedWeight(int client)
{
    return GetEntData(client, g_offset[O_CarriedWeight]);
}

stock int GetAmmoCarriedWeight(int client)
{
    static int weigth, i;
    weigth = 0;
    for(i=O_AMMO_9MM; i<O_AMMO_Grenade; ++i)
    {
        weigth += GetEntData(client, g_offset[O_Ammo] + i * 4) * cv_inv_ammoweight;
    }

    // O_AMMO_Grenade | O_AMMO_Molotov | O_AMMO_TNT | 已经计算在 1 号背包中
    // weigth += GetEntData(client, g_offset[O_Ammo] + i * 4) * 100;

    for(i=O_AMMO_ARROW; i<O_AMMO_Total; ++i)
    {
        weigth += GetEntData(client, g_offset[O_Ammo] + i * 4) * cv_inv_ammoweight;
    }

    return weigth;
}

stock int GetCarriedWeight(int client)
{
    return GetInventory1CarriedWeight(client) + GetAmmoCarriedWeight(client);
}

stock int GetObserverMode(int client)
{
    return GetEntData(client, g_offset[O_ObserverMode]);
}

stock int GetObserverTarget(int client)
{
    return GetEntDataEnt2(client, g_offset[O_ObserverTarget]);
}


// By Dysphie (Player Pings)
// @return Entity index or -1 for no collision.
stock int GetAimEntity(int client)
{
    static float eyeAng[3], eyePos[3], startPos[3], EndPos[3];

    GetClientEyeAngles(client, eyeAng);
    GetClientEyePosition(client, eyePos);
    ForwardVector(eyePos, eyeAng, 16.0, startPos);
    ForwardVector(eyePos, eyeAng, cv_target_range, EndPos);

    static Handle trace;
    static int entity;

    // Start with an accurate trace ray
    trace = TR_TraceRayFilterEx(startPos, EndPos, MASK_VISIBLE, RayType_EndPoint, TraceFilterAimEntity, client);
    entity = TR_GetEntityIndex(trace);
    delete trace;

    if( entity && IsValidEntity(entity) )   // Check if we hit an entity with the ray ( not included world )
    {
        return entity;
    }

    if( cv_trace_hull )
    {
        // If we hit nothing, try again using a swept hull
        trace = TR_TraceHullFilterEx(startPos, EndPos, g_hullMins, g_hullMaxs, MASK_VISIBLE, TraceFilterAimEntity, client);
        entity = TR_GetEntityIndex(trace);
        delete trace;

        if( IsValidEntity(entity) )         // Including world
        {
            return entity;
        }
    }
    return -1;
}

stock bool TraceFilterAimEntity(int entity, int contentMask, int ignore)
{
    return entity != ignore;
}

stock void ForwardVector(const float vPos[3], const float vAng[3], float fDistance, float vReturn[3])
{
    static float vDir[3];
    GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
    vReturn[0] = vPos[0] + vDir[0] * fDistance;
    vReturn[1] = vPos[1] + vDir[1] * fDistance;
    vReturn[2] = vPos[2] + vDir[2] * fDistance;
}

stock void SetHullSize()
{
    g_hullMins[0] = -cv_trace_width;
    g_hullMins[1] = -cv_trace_width;
    g_hullMins[2] = -cv_trace_width;

    g_hullMaxs[0] = cv_trace_width;
    g_hullMaxs[1] = cv_trace_width;
    g_hullMaxs[2] = cv_trace_width;
}

// ========================================================================================================================================================================

void Global_Timer_On()
{
    Global_Timer_Off();
    g_timer = CreateTimer(cv_update_interval, Timer_Global, _, TIMER_REPEAT);
}

void Global_Timer_Off()
{
    if( g_timer != null || g_timer != INVALID_HANDLE )
    {
        delete g_timer;
    }
}

// ========================================================================================================================================================================

void SendMessageText(int client, char[] text)
{
    static Handle message;
    static int len;

    len = strlen(text);
    if( len > 1 )
    {
        text[len - 1] = '\0';       // 删除换行符
        SendMessage(client, text);
        message = StartMessageOne("KeyHintText", client);
        BfWriteByte(message, 1);
        BfWriteString(message, text);
        EndMessage();
    }
}

void QuickCloseMessage(int client)
{
    SendMessage(client, "");
}

void SendMessage(int client, char[] text)
{
    static Handle message;
    message = StartMessageOne("KeyHintText", client);
    BfWriteByte(message, 1);
    BfWriteString(message, text);
    EndMessage();
}

// ========================================================================================================================================================================

void CustomCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ShowMenuClientPrefs(client, 0);
}

void ShowMenuClientPrefs(int client, int at=0)
{
    Menu menu_cookie = new Menu(MenuHandler_Cookies, MenuAction_Select | MenuAction_Cancel);
    menu_cookie.ExitBackButton = true;
    menu_cookie.SetTitle("%T   "...PLUGIN_VERSION..."\n \n%T\n ", "phrase_prefix_menu", client, "phrase_menu_title", client);

    CustomAddItem(menu_cookie, client, BIT_SHOW_ENABLED,                "phrase_menu_show_enabled");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AT_DEATH,               "phrase_menu_at_death");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_NAME,              "phrase_menu_show_self_name");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_HEALTH,            "phrase_menu_show_self_health");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_STAMINA,           "phrase_menu_show_self_stamina");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_SPEED,             "phrase_menu_show_self_speed");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_SPEED_VERTICAL,    "phrase_menu_show_self_speed_vertical");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_CLIP,              "phrase_menu_show_self_clip");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_INVENTORY,         "phrase_menu_show_self_inventory");
    CustomAddItem(menu_cookie, client, BIT_SHOW_SELF_STATUS,            "phrase_menu_show_self_status");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM,                    "phrase_menu_show_aim");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM_PLAYER,             "phrase_menu_show_aim_player");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM_PLAYER_NAME,        "phrase_menu_show_aim_player_name");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM_ZOMBIE,             "phrase_menu_show_aim_zombie");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM_AMMO,               "phrase_menu_show_aim_ammo");
    CustomAddItem(menu_cookie, client, BIT_SHOW_AIM_ITEM,               "phrase_menu_show_aim_item");
    CustomAddItem(menu_cookie, client, BIT_SHOW_DIVIDER,                "phrase_menu_show_divider");

    menu_cookie.DisplayAt(client, at, 30);
}

int MenuHandler_Cookies(Menu menu, MenuAction action, int param1, int param2)
{
    switch( action )
    {
        case MenuAction_Cancel:
        {
            delete menu;
            switch( param2 )
            {
                case MenuCancel_ExitBack:
                {
                    ShowCookieMenu(param1);
                }
            }
            return 0;
        }
        case MenuAction_Select:
        {
            int item_bit;
            char item_info[16];   // int - bit info

            menu.GetItem(param2, item_info, sizeof(item_info));
            item_bit = StringToInt(item_info);

            g_client_cookie[param1] ^= item_bit;
            g_cookie.SetInt(param1, g_client_cookie[param1]);

            ShowMenuClientPrefs(param1, param2 / 7 * 7);

            if( item_bit & BIT_SHOW_ENABLED && ! CheckClientPerf(param1, BIT_SHOW_ENABLED) )
            {
                QuickCloseMessage(param1);
            }
        }
    }
    return 0;
}

stock void CustomAddItem(Menu menu, int client, int bit_info, char[] phrase_key)
{
    char item_info[16], item_display[128];

    FormatEx(item_display, sizeof(item_display), "%T - %T", phrase_key, client, g_client_cookie[client] & bit_info ? "Yes" : "No", client);
    IntToString(bit_info, item_info, sizeof(item_info));

    menu.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);
}

stock bool CheckClientPerf(int client, int bit_info)
{
    return (g_client_cookie[client] & bit_info) != 0 ;
}
