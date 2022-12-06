package;

import Alphabet;
import Controls;
import TitleState;
import editors.MasterEditorMenu;
import flixel.addons.ui.*;
import flixel.math.*;
import flixel.group.FlxGroup;
import flixel.ui.FlxButton;

// cringe

class TestState extends MusicBeatState{
	var UI_box:FlxUITabMenu;
	var alphGroup:FlxTypedGroup<FlxBasic>;
	var titlGroup:FlxTypedGroup<FlxBasic>;

	////
	public var camGame:FlxCamera = new FlxCamera();
	public var camHUD:FlxCamera = new FlxCamera();

	var camFollow = new FlxPoint(640, 360);
	var camFollowPos = new FlxObject(640, 360, 1, 1);

	override function create()
	{
		FlxG.mouse.visible = true;

		// Set up cameras
		camHUD.bgColor = 0x00000000;
		camGame.follow(camFollowPos);

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		////
		var tabs = [
			{name: 'Alphabet', label: 'Alphabet'},
			{name: 'Title Screen', label: 'Title Screen'}
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(250, 200);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		UI_box.selected_tab_id = 'Alphabet';

		alphGroup = createAlphabetUI();
		titlGroup = createTitleUI();

		super.create();
	}

	var updateFunction:Void->Void;
	var lastGroup:FlxTypedGroup<FlxBasic>;
	var curGroup:FlxTypedGroup<FlxBasic>;

	function disableVolumeKeys(){
		FlxG.sound.muteKeys = [];
		FlxG.sound.volumeDownKeys = [];
		FlxG.sound.volumeUpKeys = [];
	}
	function enableVolumeKeys(){
		FlxG.sound.muteKeys = StartupState.muteKeys;
		FlxG.sound.volumeDownKeys = StartupState.volumeDownKeys;
		FlxG.sound.volumeUpKeys = StartupState.volumeUpKeys;
	}
	
	override function update(elapsed:Float)
	{
		if (updateFunction != null)
			updateFunction();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
			MusicBeatState.playMenuMusic();
		}

		if (UI_box != null){
			switch (UI_box.selected_tab_id){
				case "Alphabet":
					curGroup = alphGroup;
				case "Title Screen":
					curGroup = titlGroup;
			}
		}

		if (curGroup != lastGroup){
			remove(lastGroup);
			add(curGroup);

			lastGroup = curGroup;
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 2.4, 0, 1);
		camFollowPos.setPosition(FlxMath.lerp(camFollowPos.x, camFollow.x, lerpVal), FlxMath.lerp(camFollowPos.y, camFollow.y, lerpVal));
		
		super.update(elapsed);
	}
	
	function createAlphabetUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();

		camGame.bgColor = 0xFFFFFFFF;
		group.add(UI_box);

		var alphabetInstance = new Alphabet(0, 0, "sowy", true);
		alphabetInstance.screenCenter();
		alphabetInstance.cameras = [camHUD];
		group.add(alphabetInstance);

		////
		var inputText = new FlxUIInputText(10, 40, 230, 'abcdefghijklmnopqrstuvwxyz', 8);
		inputText.cameras = [camHUD];
		var boldCheckbox:FlxUICheckBox = new FlxUICheckBox(10, 70, null, null, "Bold", 100);
		boldCheckbox.cameras = [camHUD];

		function updateText(){			
			alphabetInstance.isBold = boldCheckbox.checked;
			alphabetInstance.changeText(inputText.text);
			alphabetInstance.screenCenter();
		}
		updateText();
		
		////
		inputText.focusGained = function(){
			disableVolumeKeys();
			updateFunction = function(){ if (FlxG.keys.justPressed.ENTER) inputText.focusLost();}
		};
		inputText.focusLost = function(){
			enableVolumeKeys();

			inputText.hasFocus = false;
			updateFunction = null;
			updateText();
		};
		group.add(inputText);
		
		boldCheckbox.callback = updateText;
		group.add(boldCheckbox);

		var woo:Bool = false;
		var changeButton = new FlxButton(10, 100, "toUpperCase");
		changeButton.cameras = [camHUD];
		changeButton.onUp.callback = function()
		{
			inputText.text = woo ? inputText.text.toLowerCase() : inputText.text.toUpperCase();
			changeButton.text = woo ? "toUpperCase" : "toLowerCase";
			woo = !woo;
			
			updateText();
		}
		group.add(changeButton);

		////
		return group;
	}

	function createTitleUI()
	{
		var group = new FlxTypedGroup<FlxBasic>();
		//var titleNames = Paths.getFolders("images/titles");
		//trace(titleNames);

		////
		var bgGroup = new FlxTypedGroup<FlxBasic>();
		group.add(bgGroup);
		var bg = new Stage("stage1").buildStage();
		bgGroup.add(bg);

		group.add(UI_box);

		/*
		var logoBl = new FlxSprite();
		function switchLogo(sowy:Int = 0){
			logoBl.frames = Paths.getSparrowAtlas('titles/${titleNames[sowy]}/logoBumpin');
			logoBl.antialiasing = true;
			logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
			logoBl.animation.play('bump');
			logoBl.setGraphicSize(Std.int(logoBl.width * 0.72));
			logoBl.scrollFactor.set();
			logoBl.updateHitbox();
			logoBl.screenCenter(XY);
		}
		switchLogo();

		group.add(logoBl);

		////
		var titleStepper = new FlxUINumericStepper(10, 40, 1, 0, 0, titleNames.length-1, 0);
		group.add(titleStepper);
		 */
		
		var stageNames = Stage.getStageList();
		var bgStepper = new FlxUINumericStepper(10, 70, 1, 0, 0, stageNames.length-1, 0);
		bgStepper.cameras = [camHUD];
		group.add(bgStepper);

		function updateStage(){
			// switchLogo(Std.int(titleStepper.value));
			bgGroup.remove(bg);
			bg.destroy();
			bg = new Stage(stageNames[Std.int(bgStepper.value)]).buildStage();

			camGame.zoom = bg.stageData.defaultZoom;

			var camPos = bg.stageData.camera_stage;
			if (camPos == null)
				camPos = [640, 360];

			camFollow.set(camPos[0], camPos[1]);
			camFollowPos.setPosition(camPos[0], camPos[1]);

			bgGroup.add(bg);
		}

		var changeButton = new FlxButton(10, 100, "Set", updateStage);
		changeButton.cameras = [camHUD];
		group.add(changeButton);

		updateStage();

		return group;
	}
}