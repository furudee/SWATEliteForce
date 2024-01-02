// ====================================================================
//  Class:  SwatGui.SwatMPLoadoutPanel
//  Parent: SwatGUIPanel
//
//  Menu to load map from entry screen.
// ====================================================================

class SwatMPLoadoutPanel extends SwatLoadoutPanel
    ;

var array<class> ServerDisabledEquipment;

var enum LoadOutOwner
{
    LoadOutOwner_Player,
    LoadOutOwner_RedOne,
    LoadOutOwner_RedTwo,
    LoadOutOwner_BlueOne,
    LoadOutOwner_BlueTwo
} ActiveLoadOutOwner;

import enum EMPMode from Engine.Repo;
import enum EEntryType from SwatGame.SwatStartPointBase;

var(SWATGui) private EditInline Config GUIButton 				MyNextOfficerButton;
var(SWATGui) private EditInline Config GUIButton 				MyPreviousOfficerButton;
var(SWATGui) private EditInline Config GUIButton 				MySaveLoadoutButton;
var(SWATGui) private EditInline Config GUILabel 				MyLoadoutLabel;
var(SWATGui) private EditInline Config GUILabel 				MySpawnLabel;
var(SWATGui) private EditInline Config GUILabel 				MyEntrypointLabel;
var(SWATGui) private EditInline Config GUICheckBoxButton		MySpawnButton;
var(SWATGui) private EditInline Config GUIComboBox 				MyEntrypointBox;
var(SWATGui) private EditInline EditConst DynamicLoadOutSpec	MyCurrentLoadOuts[LoadOutOwner.EnumCount] "holds all current loadout info";

var(SWATGui) Config Localized String CurrentLoadoutString;
var private bool bHasReceivedLoadouts; // we want to retrieve loadouts only once per server, this is set to false in SwatGUIControllers OnStateChange

///////////////////////////
// Initialization & Page Delegates
///////////////////////////

function InitComponent(GUIComponent MyOwner)
{
	local int i;
	Super.InitComponent(MyOwner);
	SwatGuiController(Controller).SetMPLoadoutPanel(self);
	
	for(i = 0; i < EEntryType.EnumCount; i++)
	{
		MyEntrypointBox.AddItem( Mid( String( GetEnum(EEntryType, i) ), 3 ) );
	}
	MyEntrypointBox.SetIndex(0);
	
	MyNextOfficerButton.OnClick=OnOfficerButtonClick;
	MyPreviousOfficerButton.OnClick=OnOfficerButtonClick;
	MySpawnButton.OnClick=OnSpawnButtonClick;
	MyEntrypointBox.OnChange=OnEntrypointChange;
	MySaveLoadoutButton.OnClick=OnSaveLoadoutButtonClick;
}

function EvaluateServerDisabledEquipment()
{
	local ServerSettings Settings;
	local array<string> SplitString;
	local int i;

	Settings = ServerSettings(PlayerOwner().Level.CurrentServerSettings);

	ServerDisabledEquipment.Length = 0;

	Split(Settings.DisabledEquipment, ",", SplitString);
	for(i = 0; i < SplitString.Length; i++)
	{
		if(SplitString[i] == "")
		{
			continue;
		}
		ServerDisabledEquipment[ServerDisabledEquipment.Length] = class<Equipment>(DynamicLoadObject(SplitString[i], class'Class'));
	}
}

function LoadMultiPlayerLoadout()
{
    //create the loadout & send to the server, then destroy it
	/*
    SpawnLoadouts();
    DestroyLoadouts();
	*/
}

protected function SpawnLoadouts()
{
	local int i;
	
	EvaluateServerDisabledEquipment();
	log(self$" :: SpawnLoadouts");
    for( i = 0; i < LoadOutOwner.EnumCount; i++ )
    {
        if( MyCurrentLoadOuts[ i ] != None )
            continue;
        
        ActiveLoadOutOwner=LoadOutOwner(i); 		// FIXME TYPE MISMATCH
        LoadLoadOut( GetConfigName(ActiveLoadOutOwner), true );
    	MyCurrentLoadOuts[ i ] = MyCurrentLoadOut;
    	MyCurrentLoadOut = None;
    }
    
    ActiveLoadOutOwner = LoadOutOwner_Player;
    MyCurrentLoadOut = MyCurrentLoadOuts[ ActiveLoadOutOwner ];
	SwatGUIController(Controller).SetMPLoadOut( MyCurrentLoadOut );
	InitializeComponents();
	bHasReceivedLoadouts = true;
}

protected function DestroyLoadouts()
{
	local int i;
	
    for( i = 0; i < LoadOutOwner.EnumCount; i++ )
    {
        if( MyCurrentLoadOuts[i] != None )
            MyCurrentLoadOuts[i].destroy();
        MyCurrentLoadOuts[i] = None;
    }
	
    if( MyCurrentLoadOut != None )
        MyCurrentLoadOut.destroy();
    MyCurrentLoadOut = None;
}

///////////////////////////
//Utility functions used for managing loadouts
///////////////////////////
function LoadLoadOut( String loadOutName, optional bool bForceSpawn )
{
	// load from server
	if(!bHasReceivedLoadouts)
	{
		if( PlayerOwner().Level.IsPlayingCOOP && loadOutName != "CurrentMultiplayerLoadOut" )
		{
			SwatGamePlayerController(PlayerOwner()).GetAIOfficerLoadout(loadOutName);
		}
		Super.LoadLoadOut( loadOutName, bForceSpawn );
	}
	// load from config
	else Super.LoadLoadOut( loadOutName, false );
	
	//MyCurrentLoadOut.ValidateLoadOutSpec();
}

function SaveCurrentLoadout() {
  //SaveLoadOut( "CurrentMultiPlayerLoadout" );
}

function ChangeLoadOut( Pocket thePocket )
{
    Super.ChangeLoadOut( thePocket );
}

protected function MagazineCountChange(GUIComponent Sender) {
  local GUINumericEdit SenderEdit;
  SenderEdit = GUINumericEdit(Sender);

  Super.MagazineCountChange(Sender);

  if(ActivePocket == Pocket_PrimaryWeapon)
  {
	MyCurrentLoadOut.SetPrimaryAmmoCount(SenderEdit.Value);
  } 
  else if(ActivePocket == Pocket_SecondaryWeapon) 
  {
	MyCurrentLoadOut.SetSecondaryAmmoCount(SenderEdit.Value);
  }

  //SaveCurrentLoadout();
}


function bool CheckValidity( class EquipmentClass, eNetworkValidity type )
{
	local int i;

	// Check for server disabled equipment
	for(i = 0; i < ServerDisabledEquipment.Length; i++)
	{
		if(EquipmentClass == ServerDisabledEquipment[i])
		{
			return false;
		}
	}

    return (type == NETVALID_MPOnly) || (Super.CheckValidity( EquipmentClass, type ));
}

function bool CheckCampaignValid( class EquipmentClass )
{
	local int MissionIndex;
	local int i;
	local int CampaignPath;
	local ServerSettings Settings;

	Settings = ServerSettings(PlayerOwner().Level.CurrentServerSettings);

	MissionIndex = (Settings.CampaignCOOP & -65536) >> 16;
	CampaignPath = Settings.CampaignCOOP & 65535;

	// Any equipment above the MissionIndex is currently unavailable
	if(Settings.IsCampaignCOOP() && CampaignPath == 0 && !Settings.bIsQMM)
	{	// We only do this for the original career, not for QMM coop
    	// Check first set of equipment
		for (i = MissionIndex + 1; i < class'SwatGame.SwatVanillaCareerPath'.default.Missions.Length; ++i)
			if (class'SwatGame.SwatVanillaCareerPath'.default.UnlockedEquipment[i] == EquipmentClass)
				return false;

	    // Check second set of equipment
		for(i = class'SwatGame.SwatVanillaCareerPath'.default.Missions.Length + MissionIndex + 1;
			i < class'SwatGame.SwatVanillaCareerPath'.default.UnlockedEquipment.Length;
			++i)
	      if(class'SwatGame.SwatVanillaCareerPath'.default.UnlockedEquipment[i] == EquipmentClass)
	        return false;
	}
	return true;
}

function bool CheckWeightBulkValidity()
{
	local float Weight;
	local float Bulk;

	Weight = MyCurrentLoadOut.GetTotalWeight();
	Bulk = MyCurrentLoadOut.GetTotalBulk();

	if(Weight > MyCurrentLoadOut.GetMaximumWeight())
	{
	    TooMuchWeightModal();
	    return false;
	}
	else if(Bulk > MyCurrentLoadOut.GetMaximumBulk())
	{
	    TooMuchBulkModal();
	    return false;
	}
	else if(MyCurrentLoadout.LoadOutSpec[0] == class'SwatEquipment.NoWeapon' &&
	  			MyCurrentLoadOut.LoadOutSpec[2] == class'SwatEquipment.NoWeapon')
	{
		NoWeaponModal();
		return false;
	}

	return true;
}

private function OnOfficerButtonClick(GuiComponent Sender)
{
	switch(Sender)
	{
		case MyNextOfficerButton:
			if( ActiveLoadOutOwner == LoadOutOwner_BlueTwo )
				ActiveLoadOutOwner = LoadOutOwner_Player;
			else ActiveLoadOutOwner = LoadOutOwner(ActiveLoadOutOwner + 1); // FIXME TYPE MISMATCH
			break;
		case MyPreviousOfficerButton:
			if( ActiveLoadOutOwner == LoadOutOwner_Player )
				ActiveLoadOutOwner = LoadOutOwner_BlueTwo;
			else ActiveLoadOutOwner = LoadOutOwner(ActiveLoadOutOwner - 1);	// FIXME TYPE MISMATCH
	}

	LoadLoadOut( GetConfigName(ActiveLoadOutOwner), false );
	InitializeComponents();
	InitialDisplay();
	//log(self$"::OnOfficerButtonClick | ActiveLoadOutOwner: "$ActiveLoadOutOwner);
}

private function OnSpawnButtonClick(GuiComponent Sender)
{
	MyCurrentLoadOut.bSpawn = MySpawnButton.bChecked;
}

private function OnEntrypointChange(GuiComponent Sender)
{
	MyCurrentLoadOut.Entrypoint = EEntryType( MyEntrypointBox.GetIndex() );
}

private function InitializeComponents()
{	
	if( !PlayerOwner().Level.IsPlayingCOOP )
	{
        MyNextOfficerButton.Hide();
		MyNextOfficerButton.DeActivate();
        MyPreviousOfficerButton.Hide();
		MyPreviousOfficerButton.DeActivate();
        MySpawnButton.Hide();
		MySpawnButton.DeActivate();
        MyEntrypointBox.Hide();
		MyEntrypointBox.DeActivate();
        MyLoadoutLabel.Hide();
        MyEntrypointLabel.Hide();
        MySpawnLabel.Hide();
        return;
	}
	else
	{
		MyNextOfficerButton.Show();
		MyNextOfficerButton.Activate();
        MyPreviousOfficerButton.Show();
		MyPreviousOfficerButton.Activate();
        MySpawnButton.Show();
		MySpawnButton.Activate();
        MyEntrypointBox.Show();
		MyEntrypointBox.Activate();
        MyLoadoutLabel.Show();
        MyEntrypointLabel.Show();
        MySpawnLabel.Show();
	}
	
	if(ActiveLoadOutOwner == LoadOutOwner_Player || MyCurrentLoadOut == None)
	{
		MySpawnButton.SetChecked( true );
		MySpawnButton.DisableComponent();
		MyEntrypointBox.DisableComponent();
	}
	else
	{
		MySpawnButton.SetChecked( MyCurrentLoadOut.bSpawn );
		MyEntrypointBox.SetIndex( MyCurrentLoadOut.Entrypoint );
		MySpawnButton.EnableComponent();
		MyEntrypointBox.EnableComponent();
	}
	
	MyLoadoutLabel.SetCaption( FormatTextString( CurrentLoadoutString, GetHumanReadableLoadout(GetConfigName(ActiveLoadOutOwner)) ) );
}

private function OnSaveLoadoutButtonClick(GuiComponent Sender)
{
	/*
	PlayerOwner().ClientMessage(
		"Saving loadout for: "$GetHumanReadableLoadout( GetConfigName(ActiveLoadOutOwner) )$
		" | Spawn: "$MySpawnButton.bChecked$
		" | Entrypoint: "$Mid( GetEnum( EEntryType, MyEntrypointBox.GetIndex() ), 3 ), 'Say');
	*/
	
	SaveLoadOut( GetConfigName(ActiveLoadOutOwner) );
	if(ActiveLoadOutOwner != LoadOutOwner_Player)
	{
		SwatGamePlayerController(PlayerOwner()).SetAIOfficerLoadout( GetConfigName(ActiveLoadOutOwner) );
	}
	else
	{
		SwatGUIController(Controller).SetMPLoadOut( MyCurrentLoadOut );
	}
}

function String GetConfigName( LoadOutOwner theOfficer )
{
    local String ret;
    switch (theOfficer)
    {
        case LoadOutOwner_Player:
            ret="CurrentMultiplayerLoadOut";
            break;
        case LoadOutOwner_RedOne:
            ret="CurrentMultiplayerOfficerRedOneLoadOut";
            break;
        case LoadOutOwner_RedTwo:
            ret="CurrentMultiplayerOfficerRedTwoLoadOut";
            break;
        case LoadOutOwner_BlueOne:
            ret="CurrentMultiplayerOfficerBlueOneLoadOut";
            break;
        case LoadOutOwner_BlueTwo:
            ret="CurrentMultiplayerOfficerBlueTwoLoadOut";
            break;
    }
    return ret;
}

function String GetHumanReadableLoadout( String theLoadout )
{
    local String ret;
    switch (theLoadout)
    {
		case "CurrentMultiplayerLoadOut":
            ret=PlayerOwner().GetHumanReadableName();
            break;
        case "CurrentMultiplayerOfficerBlueOneLoadOut":
			ret=class'SwatGame.OfficerBlueOne'.default.OfficerFriendlyName;
            break;
        case "CurrentMultiplayerOfficerBlueTwoLoadOut":
			ret=class'SwatGame.OfficerBlueTwo'.default.OfficerFriendlyName;
            break;
        case "CurrentMultiplayerOfficerRedOneLoadOut":
			ret=class'SwatGame.OfficerRedOne'.default.OfficerFriendlyName;
            break;
        case "CurrentMultiplayerOfficerRedTwoLoadOut":
			ret=class'SwatGame.OfficerRedTwo'.default.OfficerFriendlyName;
            break;
		default:
			ret="LoadOut";
			break;
    }
    return ret;
}

function CheckUpdatedLoadout( String updatedLoadout )
{
	local String currentLoadout;
	local DynamicLoadOutSpec newLoadout;
	local int i;
	
	log(self$"::CheckUpdatedLoadout updatedLoadout "$updatedLoadout);
	for(i = 0; i < LoadOutOwner.EnumCount; i++)
	{	
		currentLoadout = GetConfigName(LoadOutOwner(i));	// FIXME TYPE MISMATCH
		if( updatedLoadout == currentLoadout )
		{
			newLoadout = PlayerOwner().Spawn( class'DynamicLoadOutSpec', None, name( updatedLoadout ) ); 
			/*
			PlayerOwner().ClientMessage(
				"Received loadout for: "$GetHumanReadableLoadout(updatedLoadout)$
				" | Spawn: "$newLoadout.bSpawn$
				" | Entrypoint: "$Mid( GetEnum( EEntryType, newLoadout.Entrypoint ), 3)$
				" | Edited by: "$newLoadout.Editor, 'Say');
			
			log(
				"Received loadout for: "$GetHumanReadableLoadout(updatedLoadout)$
				" | Spawn: "$newLoadout.bSpawn$
				" | Entrypoint: "$Mid( GetEnum( EEntryType, newLoadout.Entrypoint ), 3)$
				" | Edited by: "$newLoadout.Editor);
			*/
			// has not returned from first SpawnLoadouts() so its handled there
			if(MyCurrentLoadOuts[i] == None)
			{
				newLoadout.destroy();
				continue;
			}
			MyCurrentLoadOuts[i].destroy();
			MyCurrentLoadOuts[i] = newLoadout;
			currentLoadout = GetConfigName(ActiveLoadOutOwner);
			if(currentLoadout == updatedLoadout)
			{
				MyCurrentLoadOut = MyCurrentLoadOuts[i];
				InitializeComponents();
			}
			InitialDisplay();
			break;
		}
	}
}

function SetHasReceivedLoadouts(bool in)
{
	bHasReceivedLoadouts = in;
}

defaultproperties
{
  EquipmentOverWeightString="You are equipped with too much weight. Your loadout will be changed to the default if you don't adjust it."
  EquipmentOverBulkString="You are equipped with too much bulk. Your loadout will be changed to the default if you don't adjust it."
  NoWeaponString="You do not have a weapon. Your loadout will be changed to the default if you don't adjust it."
  CurrentLoadoutString="Currently selected loadout: %1"
}
