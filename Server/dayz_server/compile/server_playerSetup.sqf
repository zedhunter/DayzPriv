private ["_characterID", "_doLoop", "_playerID", "_playerObj", "_randomSpot", "_primary", "_key", "_worldspace", "_score", "_position", "_pos", "_isIsland", "_medical", "_stats", "_state", "_dummy", "_debug", "_distance", "_hit", "_fractures", "_w", "_findSpot", "_humanity", "_clientID"];//Set Variables

#include "\@dayzcc\addons\dayz_server_config.hpp"

// Set Variables
_characterID 	= _this select 0;
_playerObj 		= _this select 1;
_playerID 		= getPlayerUID _playerObj;

if (isNull _playerObj or !isPlayer _playerObj) exitWith {
	diag_log ("PLAYER: SETUP FAILED: Player Object Null");
};

if (_playerID == "") then {
	_playerID = getPlayerUID _playerObj;
};

if (_playerID == "") exitWith {
	diag_log ("PLAYER: SETUP FAILED: No Player ID");
};

private ["_dummy"];
_dummy = getPlayerUID _playerObj;
if ( _playerID != _dummy ) then { _playerID = _dummy; };

// Variables
_worldspace 	= [];
_state 			= [];
_primary		= null;

// Connection Attempt
_doLoop = 0;
while {_doLoop < 5} do {
	_key = format["CHILD:102:%1:", _characterID];
	_primary = _key call server_hiveReadWrite;
	if (count _primary > 0) then { if ((_primary select 0) != "ERROR") then { _doLoop = 9; }; };
	_doLoop = _doLoop + 1;
};

_playerObj addMPEventHandler ["MPHit", {_this spawn server_playerHit;}];
diag_log ("PLAYER: SETUP: Hit Event added");

_medical 		= _primary select 1;
_stats 			= _primary select 2;
_state 			= _primary select 3;
_worldspace 	= _primary select 4;
_humanity 		= _primary select 5;
_randomSpot 	= false;
_distanceValue 	= 2000;
_isIsland 		= false;
_coastSpawn 	= 0;

if (worldName in ["lingor", "fallujah", "panthera2", "takistan", "zargabad"]) then {
	_distanceValue 	= 500;
	_isIsland 		= true;
	_coastSpawn 	= 1;
};

if (count _worldspace > 0) then {
	_position 		= _worldspace select 1;
	_distance 		= getMarkerpos "respawn_west" distance _position;

	if (count _position < 3) then { _randomSpot = true; };
	if (_distance < _distanceValue) then { _randomSpot = true; };
} else {
	_randomSpot = true;
};

diag_log ("PLAYER: LOGIN RESULT: " + str(_worldspace) + " [" + str(_randomSpot) + "]");

if (count _medical > 0) then {
	_playerObj setVariable ["USEC_isDead",(_medical select 0), true];
	_playerObj setVariable ["NORRN_unconscious", (_medical select 1), true];
	_playerObj setVariable ["USEC_infected",(_medical select 2), true];
	_playerObj setVariable ["USEC_injured",(_medical select 3), true];
	_playerObj setVariable ["USEC_inPain",(_medical select 4), true];
	_playerObj setVariable ["USEC_isCardiac",(_medical select 5), true];
	_playerObj setVariable ["USEC_lowBlood",(_medical select 6), true];
	_playerObj setVariable ["USEC_BloodQty",(_medical select 7), true];	
	_playerObj setVariable ["unconsciousTime",(_medical select 10), true];

	// Add Wounds
	{
		_playerObj setVariable [_x, true, true];
		["usecBleed",[_playerObj, _x, _hit]] call broadcastRpcCallAll;
	} forEach (_medical select 8);
	
	// Add fractures
	_fractures = (_medical select 9);
	_playerObj setVariable ["hit_legs",(_fractures select 0), true];
	_playerObj setVariable ["hit_hands",(_fractures select 1), true];
	
	if (count _medical > 11) then {
		_playerObj setVariable ["messing",(_medical select 11), true];
	};
	
} else {
	// Reset Fractures
	_playerObj setVariable ["hit_legs", 0, true];
	_playerObj setVariable ["hit_hands", 0, true];
	_playerObj setVariable ["USEC_injured", false, true];
	_playerObj setVariable ["USEC_inPain", false, true];
	_playerObj setVariable ["messing",[0, 0], true];
};
	
if (count _stats > 0) then {	
	// Register stats
	_playerObj setVariable ["zombieKills", (_stats select 0), true];
	_playerObj setVariable ["headShots", (_stats select 1), true];
	_playerObj setVariable ["humanKills", (_stats select 2), true];
	_playerObj setVariable ["banditKills", (_stats select 3), true];
	_playerObj addScore (_stats select 1);
	_score = score _playerObj;
	_playerObj addScore ((_stats select 0) - _score);
	_playerObj setVariable ["zombieKills_CHK", (_stats select 0)];
	_playerObj setVariable ["headShots_CHK", (_stats select 1)];
	_playerObj setVariable ["humanKills_CHK", (_stats select 2)];
	_playerObj setVariable ["banditKills_CHK", (_stats select 3)];

	if (count _stats > 4) then {
		if (!(_stats select 3)) then { _playerObj setVariable ["selectSex", true, true]; };
	} else {
		_playerObj setVariable ["selectSex", true, true];
	};
} else {
	_playerObj setVariable ["zombieKills", 0, true];
	_playerObj setVariable ["humanKills", 0, true];
	_playerObj setVariable ["banditKills", 0, true];
	_playerObj setVariable ["headShots", 0, true];
	_playerObj setVariable ["zombieKills_CHK", 0];
	_playerObj setVariable ["humanKills_CHK", 0, true];
	_playerObj setVariable ["banditKills_CHK", 0, true];
	_playerObj setVariable ["headShots_CHK", 0];
};

if (_randomSpot) then {
	private["_counter", "_position", "_isNear", "_isZero", "_mkr"];
	
	if (!isDedicated) then { endLoadingScreen; };
	
	// Spawn into random
	_findSpot = true;
	_mkr = "";
	while {_findSpot} do {
		_counter = 0;
		
		while {_counter < 20 and _findSpot} do {
			_mkr 		= "spawn" + str(round(random 4)); // Read random spawn marker from mission
			_position 	= ([(getMarkerPos _mkr), 0, 1500, 10, 0, 2000, _coastSpawn] call BIS_fnc_findSafePos); // Get position from spawn marker
			_isNear 	= count (_position nearEntities ["Man", 100]) == 0; // Another player near?
			_isZero 	= ((_position select 0) == 0) and ((_position select 1) == 0);

			if (!_isIsland) then {
				_pos = _position;
				for [{_w = 0}, {_w <= 150}, {_w = _w + 2}] do {
					_pos = [(_pos select 0), ((_pos select 1) + _w), (_pos select 2)];
					if (surfaceisWater _pos) exitWith { _isIsland = true; };
				};
			};

			if (_isNear and !_isZero) then { _findSpot = false };
			
			_counter = _counter + 1;
		};
	};
	
	_isZero 	= ((_position select 0) == 0) and ((_position select 1) == 0);
	_position 	= [_position select 0, _position select 1, 0];
	
	if (!_isZero) then {
		_worldspace = [0, _position];
		diag_log ("PLAYER: SETUP RESULT: " + str(_position) + " [" + _mkr + "]");
	} else {
		diag_log ("PLAYER: SETUP ERROR: Position Null");
	};
};

// Record player for management
dayz_players set [count dayz_players, _playerObj];

// Record player position locally for server checking
_playerObj setVariable ["characterID", _characterID, true];
_playerObj setVariable ["humanity", _humanity, true];
_playerObj setVariable ["humanity_CHK", _humanity];
_playerObj setVariable ["lastPos", getPosATL _playerObj];

dayzPlayerLogin2 = [_worldspace, _state];
_clientID = owner _playerObj;
_clientID publicVariableClient "dayzPlayerLogin2";

// Record time started
_playerObj setVariable ["lastTime", time];

diag_log ("PLAYER: LOGIN PUBLISHED: " + str(_playerObj));

// Clean up
dayzLogin 	= null;
dayzLogin2 	= null;