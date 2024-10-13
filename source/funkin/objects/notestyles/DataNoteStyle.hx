package funkin.objects.notestyles;

import funkin.scripts.FunkinHScript;
import funkin.objects.shaders.ColorSwap;
import funkin.data.NoteStyles;

class DataNoteStyle extends BaseNoteStyle
{
	var script:FunkinHScript;

	private static function structureToMap(st):Map<String, Dynamic> {
		return [
			for (k in Reflect.fields(st)){
				k => Reflect.field(st, k);
			}
		];
	}

	private static function getData(name:String):NoteStyleData {
		var path = Paths.getPath('notestyles/$name.json');
		var json = Paths.getJson(path);
		if (json == null) return null;

		var assetsMap = structureToMap(json.assets);
		json.assets = assetsMap;
		if (json.scale == null) json.scale = 1.0;

		for (name => asset in assetsMap) {
			asset.canBeColored = asset.canBeColored != false;
			//if (asset.scale == null) asset.scale = 1.0;
			if (asset.alpha == null) asset.alpha = 1.0;

/* 			if (asset.animations != null)
				asset.animations = structureToMap(asset.animations); */
		}

		return cast json;
	}

	public static function getDefault():DataNoteStyle {
		return new DataNoteStyle('default', getData('default'));
	}

	public static function fromName(name:String):Null<DataNoteStyle> {
		var data = getData(name);
		return data == null ? null : new DataNoteStyle(name, data);
	}

	final loadedNotes:Array<Note> = []; 
	final data:NoteStyleData;

	private function new(id:String, data:NoteStyleData) {
		this.data = data;
		this.scale = data.scale;

		// maybe this can be moved to fromName? idk lol
		var scriptPath:String = Paths.getHScriptPath('notestyles/$id');

		if (scriptPath != null) {
			script = FunkinHScript.fromFile(scriptPath, scriptPath, [
				"this" => this,
				"getStyleData" => (() -> return this.data)
			], false);
		}
		super(id);
	}

	function updateColours(note:Note):Void {
		var hsb:Array<Int> = note.isQuant ? ClientPrefs.quantHSV[Note.quants.indexOf(note.quant)] : ClientPrefs.arrowHSV[note.column];
		var colorSwap:ColorSwap = note.colorSwap;

		if (colorSwap != null) {
			(hsb == null) ? colorSwap.setHSB() : colorSwap.setHSB(
				hsb[0] / 360, 
				hsb[1] / 100, 
				hsb[2] / 100
			);
		}
	}

	function getNoteAsset(note:Note):Null<NoteStyleAsset> {
		var usingQuants = ClientPrefs.noteSkin=="Quants";

		var name:String = switch(note.holdType) {
			default: "tap";
			case PART: "hold";
			case END: "holdEnd";
			// what abt rolls
			// maybe note.holdSubtype??
			// NORMAL and ROLL
			// then we can just .replace("hold", "roll") if subType == ROLL
			// then everything the roll script does we can just hardcode because honestly dont think it needs to be soft-coded
		}

		if (usingQuants) {
			if (data.assets.exists("QUANT" + name)){
				// hacky, replace at some point probably
				var asset = data.assets.get("QUANT" + name);
				asset.quant = true;
				return asset;
			}
			
		}

		return data.assets.get(name);
	}

	inline function getNoteAnim(note:Note, asset:NoteStyleAnimatedAsset<Any>):Null<Any> {
		if (asset.animation != null) 
			return asset.animation 
		else if (asset.data != null)
			return asset.data[note.column % asset.data.length];
		else
			return null;
	}

	inline function loadAnimations(obj:NoteObject, asset:NoteStyleAsset)
	{
		inline function getAnimData(a:Dynamic){
			if (a is Array) {
				var data:Array<Any> = cast a;
				return data[FlxG.random.int(0, data.length - 1)];
			} else
				return a;
		}

		inline function getAnimation(animation:NoteStyleAnimationData<Any>):Null<Any>
		{
			return switch(animation.type){
				case COLUMN:
					if (animation.data == null)null;

					getAnimData(animation.data[obj.column]);

				case STATIC:
					getAnimData(animation.animation);
				default:
					null;
			}
		}

		switch(asset.type){
			case INDICES:
				var asset:NoteStyleIndicesAsset = cast asset;
				obj.loadGraphic(Paths.image(asset.imageKey), true, asset.hInd, asset.vInd);
				if(asset.animations != null){
					for(animation in asset.animations){
						var animData:Array<Int> = getAnimation(animation);
						obj.animation.add(animation.name, animData, 
							animation.framerate == null ? (asset.framerate == null ? 30 : asset.framerate) : animation.framerate);
					}
					obj.animation.play(asset.animations[0].name);
				}
			case SPARROW:
				var asset:NoteStyleIndicesAsset = cast asset;
				obj.frames = Paths.getSparrowAtlas(asset.imageKey);
				if (asset.animations != null) {
					for (animation in asset.animations) {
						var animData:String = getAnimation(animation);
						obj.animation.addByPrefix(animation.name, animData,
							animation.framerate == null ? (asset.framerate == null ? 30 : asset.framerate) : animation.framerate);
					}
					obj.animation.play(asset.animations[0].name);
				}
			case SINGLE:
				obj.loadGraphic(Paths.image(asset.imageKey));
			case SOLID:
				obj.makeGraphic(1, 1, CoolUtil.colorFromString(asset.imageKey), false, asset.imageKey);
			default:
		}
			
		
	}

	override function optionsChanged(changed) { // Maybe we should add an event to PlayState for this
		// Or maybe a global OptionsState.updated event
		// then we dont need to call this manually everywhere lol

		if (true) {
			for (note in loadedNotes)
				updateColours(note);
		}

		if(script != null)
			script.executeFunc("optionsChanged", [changed]);
		
	}

	override function noteUpdate(note:Note, dt:Float){
		if (script != null)
			script.executeFunc("noteUpdate", [note, dt]);
	}

	override function destroy(){
		super.destroy();
		// JUST to make sure shit is cleared properly lol
		loadedNotes.resize(0); 
		if (script != null)
			script.executeFunc("destroy", []);
	}

	override function unloadNote(note:Note){
		loadedNotes.remove(note);
		if (script != null)
			script.executeFunc("unloadNote", [note]);
	}
	

	override function loadNote(note:Note) {
		loadedNotes.push(note);

		var asset:NoteStyleAsset = getNoteAsset(note);
		note.isQuant = asset.quant ?? false;

		switch (asset.type) {
			case SPARROW: var asset:NoteStyleSparrowAsset = cast asset;
				note.frames = Paths.getSparrowAtlas(asset.imageKey);

				var anim:String = getNoteAnim(note, asset);
				note.animation.addByPrefix('', anim); // might want to use the json anim name, whatever
				note.animation.play('');


			case INDICES: var asset:NoteStyleIndicesAsset = cast asset;
				note.loadGraphic(Paths.image(asset.imageKey), true, asset.hInd, asset.vInd);
				
				var anim:Array<Int> = getNoteAnim(note, asset);
				note.animation.add('', anim);
				note.animation.play('');

			case SINGLE:
				note.loadGraphic(Paths.image(asset.imageKey));

			case SOLID: // lol
				note.makeGraphic(1, 1, CoolUtil.colorFromString(asset.imageKey), false, asset.imageKey);

			default: //case NONE: 
				note.makeGraphic(1,1,0,false,'invisible'); // idfk something might want to change .visible so
		}

		// note.alpha = asset.alpha;

		if (asset.antialiasing != null) {
			note.antialiasing = asset.antialiasing;
		}else {
			note.useDefaultAntialiasing = true;
		}

		if (asset.canBeColored == false) {
			note.colorSwap.hue = 0;
			note.colorSwap.brightness = 0;
			note.colorSwap.saturation = 0;
		}else
			updateColours(note);
		
		
		note.scale.x = note.scale.y = (asset.scale ?? data.scale);
		note.defScale.copyFrom(note.scale);
		note.updateHitbox();

		if (script != null)
			script.executeFunc("loadNote", [note]);

		return true; 
	}
}