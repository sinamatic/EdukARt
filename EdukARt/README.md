# EdukARt

EdukARt is a mobile mixed-reality racing game in which players use an iPhone to steer a physical robot along a self-created virtual track in their real surroundings. Collectible items and obstacles connect virtual events with the robot's movement and lighting, while bonuses and penalties affect the final race time. Players follow the robot through the environment to keep it in the camera's view.

The prototype is implemented as a native iOS application using Swift, ARKit, and RealityKit. It controls the mobile robot Eduard over its existing Wi-Fi network through a Python UDP-to-ROS2 bridge. AprilTags provide a shared two-dimensional spatial reference for the robot, course editing, interaction detection, and placement of virtual content in the physical environment. The integration retains the robot's existing drive hardware and control software.

## Accompanying bachelor's thesis

This software was developed by **Sina Steinmüller** as part of the bachelor's thesis **“EdukARt: A mixed-reality racing game for physical robot teleoperation”** for the Bachelor of Media Engineering (B. Eng.) at **Technische Hochschule Nürnberg Georg Simon Ohm**.

The [accompanying thesis repository](https://github.com/sinamatic/Docu_EduK-AR-t) contains the detailed motivation, technology selection, implementation, testing observations, and discussion of the prototype. A [prototype and gameplay demonstration](https://qrco.de/edukARt) is also available.

This README describes the prototype documented in the thesis. Version numbers and behavior below reflect that development and test setup; they are not a declaration of minimum requirements or compatibility with other configurations.

## Software and versions

| Software / platform | Documented version | Purpose |
| --- | --- | --- |
| macOS Tahoe | 26.4.1 | Development OS on a MacBook Pro with Apple M4 Max and 64 GB RAM. |
| iOS | 26.6.1 | Test OS on an iPhone 13 Pro. |
| Xcode | 26.6 | Native iOS application development and deployment. |
| Swift | Not specified | Application implementation. |
| SwiftUI | Separate version not specified | Application views and controls. |
| ARKit | Separate version not specified | Camera frames, world tracking, spatial reference, and initial LiDAR experiments. |
| RealityKit | Separate version not specified | Rendering, animation, and representation of virtual content. |
| SwiftAprilTag | Not specified | AprilTag detection; see the [SwiftAprilTag repository](https://github.com/keyqcloud/SwiftAprilTag). |
| SwiftUIJoystick | Not specified | Basis for the adapted joystick controls; see the [SwiftUIJoystick repository](https://github.com/michael94ellis/SwiftUIJoystick). |
| Pingx | Not specified | Robot network reachability checks. |
| Debian GNU/Linux | 11 (Bullseye) | Robot host OS. |
| Linux kernel | 5.10.64 | Robot host kernel. |
| Docker | 27.2.1 | Robot control and bridge containers. |
| Docker Compose | 2.29.2 | Bridge service configuration and startup. |
| EduArt robot-control image | `eduartrobotik/eduart-robot-control:0.5.0` | Existing robot-control environment. |
| Ubuntu | 24.04.1 LTS | OS inside the documented robot-control container. |
| ROS2 | Jazzy | Robot topics, services, and control interfaces. |
| Python | 3.12.3 | UDP-to-ROS2 receiver on the robot. |
| ChatGPT Pro | GPT-5.6 Sol; medium reasoning effort | AI-assisted development. |
| Adobe Photoshop | 27.8.0 | Image preparation and graphics. |
| Adobe Illustrator | 30.6 | Vector graphics, asset designs, and marker preparation. |
| Reality Composer Pro | 2.0 (494.100.6) | AR asset and material preparation. |
| Blender | 5.0.1 | 3D asset editing, materials, and geometry optimization. |
| Autodesk Fusion 360 | 2705.1.15, ARM64 (native) | CAD modeling and marker construction. |
| Bambu Studio | Not specified | Preparation of 3D-printed AprilTags. |
| Obsidian | 1.13.7 | Development and documentation notes. |
| Visual Studio Code | 1.139.1 | Thesis documentation. |
| LaTeX | Not specified | Thesis typesetting. |
| Git | Not specified | Version control. |
| DeepL / DeepL Write | Not specified | Translation assistance and linguistic revision of the thesis. |

## Physical robot: Eduard

The prototype uses **Eduard_Blue3**, a mobile robot by **EduArt Robotik GmbH**, equipped with **Mecanum wheels**. These support forward, backward, lateral, and diagonal movement as well as rotation on the spot. Eduard's four integrated lighting modules provide visible feedback for robot states and game events. The platform is designed for research, development, and education; available configurations are described on the [official Eduard product page](https://www.eduart-robotik.com/products/rd-platform-eduard).

In the tested setup, a Siemens SIMATIC IOT2000 runs the Debian host system, while the ROS2 control environment runs in Docker. EdukARt adds a generic Python bridge that receives JSON commands over UDP and publishes ROS2 messages or calls ROS2 services. Game-specific logic remains primarily in the iPhone application.

| Parameter | Tested configuration |
| --- | --- |
| Robot / Wi-Fi network | `Eduard_Blue3` |
| Kinematics | Mecanum |
| Onboard computer | Siemens SIMATIC IOT2000 |
| Robot address | `192.168.0.100` |
| UDP port | `50505` |
| ROS2 namespace | `/eduard/blue3` |
| ROS workspace | `/home/user/ros` |
| Movement topic | `/eduard/blue3/cmd_vel`, type `geometry_msgs/msg/Twist` |
| Activation service | `/eduard/blue3/set_mode`, type `edu_robot/srv/SetMode` |
| Lighting topic | `/eduard/blue3/set_lighting_color`, type `edu_robot/msg/SetLightingColor` |
| Bridge deployment directory | `/home/user/edukart_ros2_bridge/docker/iot2050` |
| Bridge Compose service | `edukart-ros2-receiver` |

The bridge supports publishing messages and calling services using interface names, types, and data supplied by the application. Command transmission is unidirectional: ROS2 status messages, service results, and errors are not returned to the app. Ping-based reachability and the app's activation state therefore do not constitute confirmed robot telemetry.

Integration was tested with this Eduard configuration. Supporting further ROS2 robots is a possible extension and requires adapting the robot-specific interfaces. EduArt documents its interfaces in the [ROS2 interface reference](https://github.com/EduArt-Robotik/edu_robot/blob/main/documentation/interface/interface.md).

## Software components

This table consolidates all component-and-responsibility tables from the thesis into one alphabetical overview. Repeated components appear once, with their responsibilities combined into bullet points. It also includes supporting views and asset-loading components described in the implementation text. Names refer to the documented source files or types; they do not imply that every entry is a Swift class. The spelling `CollissionManager.swift` follows the thesis.

| Component | Responsibilities |
| --- | --- |
| `AprilTagLocalization.swift` | • Selects and stabilizes the reference marker.<br>• Checks pose quality.<br>• Determines marker positions and orientations within the shared map coordinate system. |
| `AprilTagMapBuilder.swift` | • Collects and averages marker measurements.<br>• Checks distances to already mapped markers.<br>• Assembles the recorded map points. |
| `AprilTagMapView.swift` | • Prepares live marker-map data for display through the shared map renderer. |
| `ARTrackRenderer.swift` | • Constructs the three-dimensional road surface and boundaries from track data.<br>• Places and aligns start and finish markings. |
| `CameraARView.swift` | • Provides the camera and AR session.<br>• Detects AprilTags through SwiftAprilTag and forwards detections to localization and mapping.<br>• Loads, positions, and animates virtual game elements.<br>• Updates their representation when the game state changes.<br>• Contains `ARCoinRenderer`, which displays rotating, gently bobbing coins.<br>• Reuses the preloaded virtual Eduard model. |
| `CameraPreviewView.swift` | • Displays the live iPhone camera image in the Robot Remote camera panel. |
| `CollissionManager.swift` | • Detects entry and exit events in two-dimensional interaction areas.<br>• Checks movement commands against blocking obstacles. |
| `ContentView.swift` | • Starts asynchronous preloading of the virtual Eduard model while the opening logo is displayed. |
| `Course.swift` | • Collects track-drawing input.<br>• Removes redundant points, smooths the line, and resamples it into the processed track centerline. |
| `CoursesView.swift` | • Provides the interface for creating and managing stored courses. |
| `CreateMapView.swift` | • Hosts the Create Map, Draw Road, and Items / Obstacles stages of course creation. |
| `Eduard.swift` | • Provides the interface to the physical Eduard.<br>• Translates application requests into robot-specific commands.<br>• Sends movement commands through the ROS2 interface via the UDP bridge.<br>• Stores selected lighting colors and maps lighting requests to Eduard's modes.<br>• Generates the rainbow lighting effect.<br>• Uses Pingx for reachability checks. |
| `EduardModelStore.swift` | • Loads and retains the virtual Eduard model for reuse, reducing loading delays when opening the AR view. |
| `EduardSimulation.swift` | • Applies movement commands to the virtual Eduard and animates its wheels.<br>• Includes the simplified robot representation and occlusion component used to hide virtual content behind Eduard. |
| `edukart_ros2_receiver.py` | • Runs on the robot.<br>• Receives application commands over UDP.<br>• Passes commands to ROS2 by publishing messages or calling services. |
| `GameController.swift` | • Maintains active game state and processes interactions.<br>• Coordinates gameplay effects and haptic feedback.<br>• Generates coins along the processed track.<br>• Measures race time and maintains bonuses, penalties, and results.<br>• Stores course-specific leaderboard results locally. |
| `GameMap.swift` | • Defines object types, placement data, and object-specific properties, including models, scales, and interaction radii.<br>• Combines the reference marker, recorded marker positions and orientations, processed track, and placed objects into a complete course. |
| `GameMapStore.swift` | • Saves and loads courses locally in `game-maps.json`.<br>• Manages updates and deletion of stored courses. |
| `GameMapView.swift` | • Combines the recorded marker map with the editable track.<br>• Forwards drawing input to track processing.<br>• Creates placed objects from map input and applies object-specific placement rules. |
| `GameView.swift` | • Coordinates race preparation, countdown, and result display.<br>• Connects gameplay requests to shared robot controls.<br>• Supports restarting a race while retaining the current course alignment. |
| `JoystickMonitor` (SwiftUIJoystick) | • Stores joystick positions.<br>• Makes input changes available to the application. |
| `JoystickView.swift` | • Provides movement and rotation controls.<br>• Handles dragging and return to the neutral position.<br>• Reuses the same controls in Robot Remote and gameplay. |
| `MapCanvasView.swift` | • Provides the reusable two-dimensional display of marker positions, IDs, and orientations.<br>• Displays the track and placed objects.<br>• Captures finger movements and drag-and-drop input.<br>• Converts display and drop positions into map coordinates. |
| `RobotController.swift` | • Coordinates robot control and maintains connection and activation state across the application.<br>• Interprets joystick input and routes movement commands to the physical robot, virtual robot, or both.<br>• Maintains continuous command transmission while the physical robot is enabled.<br>• Forwards lighting-mode selections and coordinates visual feedback for game events.<br>• Applies movement restrictions, temporary control effects, and speed changes.<br>• Manages temporary lighting effects and restoration of previous lighting states where implemented. |
| `RobotControlOverlay.swift` | • Displays shared connection and activation status.<br>• Provides enable and disable controls across most screens. |
| `RobotRemoteView.swift` | • Combines connection and activation controls, joystick input, and lighting controls in Robot Remote. |
| `RobotTypes.swift` | • Defines shared drive commands, control and drive modes, and robot poses. |
| `TrackRules.swift` | • Defines the shared physical road width used for track representation: 60 cm, with boundaries 30 cm on either side of the centerline. |

## Items and obstacles

The table below combines all eight item-property tables in the thesis. Egg and egg cup are listed separately to show their individual roles and lighting durations. The prototype contains four manually placeable item types, four obstacles, and automatically generated coins. The egg cup uses the nest-with-eggs symbol shown in the course editor.

Interaction radii are the documented object, trigger, or blocking radii, not camera detection distances. Lighting refers to feedback on the physical robot; interactions also provide haptic feedback on the iPhone. Speed percentages refer to the configured maximum: normal gameplay uses an 80% speed multiplier, while damage reduces it in percentage points.

| Element | Type / placement | Interaction radius | Lighting feedback | Effect / object behavior | Gameplay impact |
| --- | --- | --- | --- | --- | --- |
| 🎁 **Itembox** | Item; manual | Object: 12 cm | Purple; fast blinking; 0.8 s | Collected and removed from the AR view. | Subtracts 20 s from the final race time per collected box. |
| 💩 **Poop** | Item; manual | Object: 12 cm | Orange; fast blinking; 5 s | Removed from the AR view when triggered; leaves a virtual brown trail. | Automatic slow zigzag movement for 5 s; joystick control is temporarily overridden. |
| 🥚 **Egg** | Item; manual | Object: 10 cm | Green; fast blinking; 0.55 s | Collected and transported by Eduard. The carried count is unlimited; one visible egg represents the collection. | Transport to an egg cup enables repair of simulated damage. |
| 🪺 **Egg cup** | Delivery item; manual | Object: 10 cm | Green; fast blinking; 1.5 s | Receives the eggs carried by Eduard. | Successful delivery restores normal gameplay speed to 80%; delivery can be repeated. |
| 🪙 **Coin** | Collectible; automatic | Object: 3.5 cm | Yellow; fast blinking; 0.55 s | Collected and removed from the AR view. Generated every 50 cm along the processed track, starting 50 cm from the start. | Raises speed to 90% for 2 s; further collections can extend the boost. Each uncollected coin adds 5 s to the final race time. |
| 🛢️ **Oil** | Persistent obstacle; manual | Trigger: 18 cm; barrel blocking: 7 cm | Light red; slow blinking; 5 s | Triggers automatic rotation for 5 s, approximately 180°; remains in place. | Temporarily overrides joystick control; blocks movement into the barrel. Each registered blocking collision reduces normal gameplay speed by 10 percentage points. Rotation cooldown: 20 s; damage cooldown: 10 s. |
| 🪨 **Stone / Rock** | Persistent obstacle; manual | Blocking: 15 cm | Dark red; slow blinking; 0.8 s | Prevents movement into its blocking area. | Each registered collision reduces normal gameplay speed by 10 percentage points; damage cooldown: 10 s per stone. |
| 🌳 **Tree** | Triggered obstacle; manual | Trigger: 18 cm; tree blocking: 10 cm | Appearance: green, fast blinking, 3 s.<br>Damage: dark red, slow blinking, 0.8 s. | Grows out of the ground when triggered. Trigger and tree are aligned with the track centerline. | Blocks the path; a collision reduces normal gameplay speed by 10 percentage points. Damage cooldown: 10 s per tree. |
| 💧 **Water** | Persistent obstacle; manual | Trigger: 40 cm | Blue; fast blinking while water mode is active | Switches movement to short swimming strokes of approximately 5 cm forward; lateral strokes cover less distance. | Repeated joystick input is required inside the puddle. The joystick must return to neutral between strokes. |

The final race time is the elapsed time **plus 5 s for each uncollected coin, minus 20 s for each collected itembox**. Movement effects and simulated damage influence the time needed to reach the finish.

## Playing the prototype

1. Connect the iPhone to `Eduard_Blue3`. Use **Robot Remote** to check connectivity, enable the robot, and test movement and lighting.
2. Arrange `tag36h11` AprilTags on the floor and mount **tag 0** on Eduard. The documented markers have a 12 cm outer dimension and a 9.6 cm black detection boundary. Floor markers must remain in their recorded positions.
3. Open **Courses → Create Course**. Scan the floor markers to create the map. Tag 0 is reserved for robot localization and excluded from floor-map creation. The reference uses 20 valid pose estimates within 1.2 m of the camera; additional markers use ten measurements and must lie within 3 m of an already mapped marker.
4. In **Draw Road**, draw one continuous track from start to finish. In **Items / Obstacles**, drag elements onto the map, then name and save the course.
5. Open **Start Game**, choose the course, and scan its highlighted reference marker to restore alignment. Position the robot behind the start, select **I'm Ready**, and wait for the countdown.
6. Follow the robot with the camera while driving, collect coins and bonuses, and reach the finish. The robot is disabled automatically at the end. Save the result under a player name and compare runs in **Scores**.

Courses are stored locally. During a race, gameplay modifies a temporary copy of the placed objects. **Start New Game** restores the saved arrangement and resets race statistics and temporary effects without another reference-marker scan in the same AR session.

## Prototype status

The thesis demonstrates technical feasibility with the tested Eduard and iPhone setup. The current implementation remains a research prototype:

- Localization depends on marker visibility, viewing distance, lighting, and the floor markers remaining in place. Following the robot closely generally improved tracking during testing.
- The final marker-based map does not automatically represent physical obstacles. LiDAR-based environmental reconstruction was explored but is not part of the final mapping workflow.
- The game does not enforce staying within the road boundaries or following the complete route. Missed-coin penalties encourage track following.
- Overlapping lighting effects can replace one another without restoring the previous effect. A consistent priority system remains future work.
- The virtual Eduard supports testing and comparison, but some behavior, particularly swimming controls, still differs from the physical robot.
- Gameplay balance, additional robot platforms, multiplayer, and cross-platform support remain areas for further development.

