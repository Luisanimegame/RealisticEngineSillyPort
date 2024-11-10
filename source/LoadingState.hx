package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import haxe.io.Path;
import lime.app.Future;
import lime.app.Promise;
import lime.utils.Assets as LimeAssets;
import lime.utils.AssetLibrary;
import lime.utils.AssetManifest;
import openfl.utils.Assets;

class LoadingState extends MusicBeatState {
	// Loading --
	var targetState:FlxState;
	var loadedPercentage:Float = 0;
	var stopMusic = false;
	var callbacks:MultiCallback;
	// -- Loading

	// Loading Screen --
	var funkayBG:FlxSprite;
	var funkayScreen:FlxSprite;
	var funkayBar:FlxSprite;
	// -- Loading Screen

	function new(targetState:FlxState, stopMusic:Bool) {
		super();
		this.targetState = targetState;
		this.stopMusic = stopMusic;
	}

	override function create() {
		funkayBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFFCAFF4D);
		add(funkayBG);

		funkayScreen = new FlxSprite().loadGraphic(Paths.image('loading/funkayLoading'));
		add(funkayScreen);
		funkayScreen.setGraphicSize(0, FlxG.height);
		funkayScreen.updateHitbox();
		funkayScreen.antialiasing = true;
		funkayScreen.scrollFactor.set();
		funkayScreen.screenCenter();

		funkayBar = new FlxSprite(0, FlxG.height - 20).makeGraphic(FlxG.width, 10, 0xFFFF16D2);
		add(funkayBar);
		funkayBar.screenCenter(X);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		var wackyWidth = FlxG.width * 0.88;
		var resizeSpeed:Float = FlxMath.lerp(wackyWidth + 0.9 * (funkayScreen.width - wackyWidth), funkayScreen.width, elapsed * 9);
		funkayScreen.setGraphicSize(Std.int(resizeSpeed));
		funkayScreen.updateHitbox();

		if(controls.ACCEPT) {
			funkayScreen.setGraphicSize(Std.int(funkayScreen.width + 60));
			funkayScreen.updateHitbox();
			#if debug
				trace('fired: ' + callbacks.getFired() + " unfired:" + callbacks.getUnfired());
			#end
		}

		if(callbacks != null) {
			loadedPercentage = FlxMath.remapToRange(callbacks.numRemaining / callbacks.length, 1, 0, 0, 1);
			funkayBar.scale.x += 0.5 * (loadedPercentage - funkayBar.scale.x);
		}
	}

	function onLoad() {
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		FlxG.switchState(targetState);
	}

	static function getSongPath() {
		return Paths.inst(PlayState.SONG.song);
	}

	static function getVocalPath() {
		return Paths.voices(PlayState.SONG.song);
	}

	inline static public function loadAndSwitchState(targetState:FlxState, stopMusic = false) {
		FlxG.switchState(getNextState(targetState, stopMusic));
	}

	static function getNextState(targetState:FlxState, stopMusic = false):FlxState {
	#if NO_PRELOAD_ALL
		var loaded:Bool;
		if(PlayState.storyWeek > 1 && PlayState.storyWeek < 7) {
			Paths.setCurrentLevel("week" + PlayState.storyWeek);
			loaded = isSoundLoaded(getSongPath()) && (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && isLibraryLoaded("week" + PlayState.storyWeek) && isLibraryLoaded("shared");
		} else {
			Paths.setCurrentLevel("shared");
			loaded = isSoundLoaded(getSongPath()) && (!PlayState.SONG.needsVoices || isSoundLoaded(getVocalPath())) && isLibraryLoaded("shared");
		}

		if (!loaded)
			return new LoadingState(targetState, stopMusic);
		#end
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return targetState;
	}

	override function destroy() {
		super.destroy();

		callbacks = null;
	}

class MultiCallback {
	public var callback:Void->Void;
	public var logId:String = null;
	public var length(default, null) = 0;
	public var numRemaining(default, null) = 0;

	var unfired = new Map<String, Void->Void>();
	var fired = new Array<String>();

	public function new (callback:Void->Void, logId:String = null) {
		this.callback = callback;
		this.logId = logId;
	}

	public function add(id = "untitled") {
		id = '$length:$id';
		length++;
		numRemaining++;

		var func:Void->Void = null;
		func = function () {
			if (unfired.exists(id)) {
				unfired.remove(id);
				fired.push(id);
				numRemaining--;

				if (logId != null)
					log('fired $id, $numRemaining remaining');

				if (numRemaining == 0) {
					if (logId != null)
						log('all callbacks fired');

					callback();
				}
			} else {
				log('already fired $id');
			}
		}
		unfired[id] = func;

		return func;
	}

	inline function log(msg):Void {
		if (logId != null)
			trace('$logId: $msg');
	}

	public function getFired() {
		return fired.copy();
	}

	public function getUnfired() {
		return [for (id in unfired.keys()) id];
	}
}