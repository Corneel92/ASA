﻿package {
	
	//--------------------------------------
	//  Imports
	//--------------------------------------
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.utils.ByteArray;
	
	import org.libspark.flartoolkit.core.FLARCode;
	import org.libspark.flartoolkit.core.param.FLARParam;
	import org.libspark.flartoolkit.core.raster.rgb.FLARRgbRaster_BitmapData;
	import org.libspark.flartoolkit.core.transmat.FLARTransMatResult;
	import org.libspark.flartoolkit.detector.FLARSingleMarkerDetector;
	import org.libspark.flartoolkit.pv3d.FLARBaseNode;
	import org.libspark.flartoolkit.pv3d.FLARCamera3D;
	
	import org.papervision3d.lights.PointLight3D;
	import org.papervision3d.materials.shadematerials.FlatShadeMaterial;
	import org.papervision3d.materials.utils.MaterialsList;
	import org.papervision3d.objects.parsers.DAE;
	import org.papervision3d.objects.primitives.Cube;
	import org.papervision3d.render.BasicRenderEngine;
	import org.papervision3d.scenes.Scene3D;
	import org.papervision3d.view.Viewport3D;
	
	
	//--------------------------------------
	//  Class Definition
	//--------------------------------------
	public class AugmentedReality extends Sprite
	{
		
		//--------------------------------------
		//  Class Properties
		//--------------------------------------

		//	1. WebCam
		private var video	: Video;		
		private var webcam	: Camera;	

		//	2. FLAR Marker Detection
		private var flarBaseNode				: FLARBaseNode;		
		private var flarParam					: FLARParam;
		private var flarCode					: FLARCode;
		private var flarRgbRaster_BitmapData	: FLARRgbRaster_BitmapData;
		private var flarSingleMarkerDetector	: FLARSingleMarkerDetector;
		private var flarCamera3D				: FLARCamera3D;		
		private var flarTransMatResult			: FLARTransMatResult;
		private var bitmapData					: BitmapData;
		private var FLAR_CODE_SIZE				: uint 		= 16;
		private var MARKER_WIDTH				: uint 		= 80;

		
		//[Embed(source="./assets/FLAR/Hiro.pat", mimeType="application/octet-stream")]
		[Embed(source="./assets/FLAR/FLARPattern2.pat", mimeType="application/octet-stream")]
		private var Pattern	: Class;
		
		[Embed(source="./assets/FLAR/FLARCameraParameters.dat", mimeType="application/octet-stream")]
		private var Params : Class;
					
		//	3. PaperVision3D
		private var basicRenderEngine	: BasicRenderEngine;
		private var viewport3D			: Viewport3D;		
		private var scene3D				: Scene3D;
		private var collada3DModel		: DAE;
	
		//	Fun, Editable Properties
		private var VIDEO_WIDTH 			: Number = 640;				//Set 100 to 1000 to set width of screen
		private var VIDEO_HEIGHT 			: Number = 480;				//Set 100 to 1000 to set height of screen
		private var WEB_CAMERA_WIDTH 		: Number = VIDEO_WIDTH/2;	//Smaller than video runs faster
		private var WEB_CAMERA_HEIGHT 		: Number = VIDEO_HEIGHT/2;	//Smaller than video runs faster
		private var VIDEO_FRAME_RATE 		: Number = 30;				//Set 5 to 30.  Higher values = smoother video
		private var DETECTION_THRESHOLD		: uint 	 = 80;				//Set 50 to 100. Set to detect marker more accurately.
		private var DETECTION_CONFIDENCE	: Number = 0.5;				//Set 0.1 to 1. Set to detect marker more accurately.
		//private var MODEL_SCALE 			: Number = 0.0175;			//Set 0.01 to 5. Set higher to enlarge model
		private var MODEL_SCALE 			: Number = 0.5;			//Set 0.01 to 5. Set higher to enlarge model
		
		//	Fun, Editable Properties: Load a Different Model
		//private var COLLADA_3D_MODEL 		: String = "./assets/models/something/test.dae";
		//private var COLLADA_3D_MODEL 		: String = "./assets/models/tower/models/tower.dae";
		private var COLLADA_3D_MODEL 		: String = "./assets/models/cube/blueCube.dae";
		//private var COLLADA_3D_MODEL 		: String = "./assets/models/oudenoord700/models/model.dae";
		//private var COLLADA_3D_MODEL 		: String = "./assets/models/Oudenoord700v2/test.dae";
		
		
		//--------------------------------------
		//  Constructor
		//--------------------------------------
		
		/**
		 * The constructor is the ideal place 
		 * for project setup since it only runs once.
		 * Prepare A,B, & C before repeatedly running D.
		**/
		public function AugmentedReality ()
		{
			//	Prepare
			prepareWebCam();  			//Step A
			prepareMarkerDetection();	//Step B
			preparePaperVision3D();  	//Step C
			
			//	Repeatedly call the loop method
			//	to detect and adjust the 3D model.
			addEventListener(Event.ENTER_FRAME, loopToDetectMarkerAndUpdate3D); //Step D
		}
		
		
		//--------------------------------------
		//  Methods
		//--------------------------------------
		
		/**
		 * A. Access the user's webcam, wire it 
		 *    to a video object, and display the
		 *    video onscreen.
		**/
		private function prepareWebCam () : void
		{
			video = new Video(VIDEO_WIDTH, VIDEO_HEIGHT);
			webcam = Camera.getCamera();
			webcam.setMode(WEB_CAMERA_WIDTH, WEB_CAMERA_HEIGHT, VIDEO_FRAME_RATE);
			video.attachCamera(webcam);
			addChild(video);
		}	
		
		
		/**
		 * B. Prepare the FLAR tools to detect with
		 *	  parameters, the marker pattern, and
		 *	  a BitmapData object to hold the information
		 *    of the most recent webcam still-frame.
		**/
		private function prepareMarkerDetection () : void
		{
			//	The parameters file corrects imperfections
			//	In the webcam's image.  The pattern file
			//	defines the marker graphic for detection
			//	by the FLAR tools.
			flarParam = new FLARParam();
			flarParam.loadARParam(new Params() as ByteArray);
			flarCode = new FLARCode (FLAR_CODE_SIZE, FLAR_CODE_SIZE);
			flarCode.loadARPatt(new Pattern());
			
			
			//	A BitmapData is Flash's version of a JPG image in memory.
			//	FLAR studies this image every frame with its
			//	marker-detection code.
			bitmapData = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
			bitmapData.draw(video);
			flarRgbRaster_BitmapData = new FLARRgbRaster_BitmapData(bitmapData);
			flarSingleMarkerDetector = new FLARSingleMarkerDetector (flarParam, flarCode, MARKER_WIDTH);
		}	
		
		
		/**
		 * C. Create PaperVision3D's 3D tools including
		 *	  a scene, a base node container to hold the
		 *	  3D Model, and the loaded 3D model itself. 
		**/		
		private function preparePaperVision3D () : void
		{
			//	Basics of the empty 3D scene fit for
			//	FLAR detection inside a 3D render engine.
			basicRenderEngine 	= new BasicRenderEngine();
			flarTransMatResult 	= new FLARTransMatResult();
			viewport3D 			= new Viewport3D();
			flarCamera3D 		= new FLARCamera3D(flarParam);
			flarBaseNode 		= new FLARBaseNode();
			scene3D 			= new Scene3D();
			scene3D.addChild(flarBaseNode);
			
			//	Load, scale, and position the model
			//	The position and rotation will be
			//	adjusted later in method D below.
			collada3DModel = new DAE ();
			collada3DModel.load(COLLADA_3D_MODEL);
			collada3DModel.scaleX = collada3DModel.scaleY = collada3DModel.scaleZ = MODEL_SCALE;
			//collada3DModel.z = 5;			//Moves Model 'Up' a Line Perpendicular to Marker
			collada3DModel.rotationX = 90;  //Rotates Model Around 2D X-Axis of Marker
			collada3DModel.rotationY = 0;   //Rotates Model Around 2D Y-Axis of Marker
			collada3DModel.rotationZ = 0;	//Rotates Model Around a Line Perpendicular to Marker

			//	Add the 3D model into the 
			//	FLAR container and add the 
			//	3D cameras view to the screen
			//	so the user can view the result
			flarBaseNode.addChild(collada3DModel);
			addChild (viewport3D);
		}	
		
		
		/**
		 * D. Detect the marker in the webcamera. If
		 *	  found: move, scale, and rotate the 
		 *	  3D model to composite it over the marker
		 *	  in the user's physical space.
		**/
		private function loopToDetectMarkerAndUpdate3D (aEvent : Event) : void
		{

			//	Copy the latest still-frame of the webcam video
			//	into the BitmapData object for detection
			bitmapData.draw(video);

			try {
				
				//	Detect *IF* the marker is found in the latest still-frame
				if(	flarSingleMarkerDetector.detectMarkerLite (flarRgbRaster_BitmapData, DETECTION_THRESHOLD) && 
					flarSingleMarkerDetector.getConfidence() > DETECTION_CONFIDENCE							) {
						
					//	Repeatedly Loop and Adjust 3D Model to Match Marker
					flarSingleMarkerDetector.getTransformMatrix(flarTransMatResult);
					flarBaseNode.setTransformMatrix(flarTransMatResult);
					basicRenderEngine.renderScene(scene3D, flarCamera3D, viewport3D);
				}
			} catch (error : Error) {}
		}
	}
}
