# SML_Eduard offline setup

The app adds SML_Eduard once, without selecting it or replacing the existing
Eduard settings. Choose Robots → SML_Eduard → Settings → ROS Settings.

1. Join the robot Wi-Fi on the iPhone. Allow local network access when asked.
2. Check host `192.168.8.100`, SSH user `user`, and the prefilled password.
3. Tap **Automatisch ausfüllen**. This executes the bundled discovery script
   over SSH; it does not install the bridge or call motor services. Review the
   resulting fields and report. Ambiguous fields retain their previous values.
4. Tap **install ROSbridge on Robot**. This stores the bundled Python script
   under `~/.local/share/edukart/<profile UUID>/` and copies it into the chosen
   running container. No package downloads, image pulls or driver restarts occur.
5. Tap **start rosbridge**. The app checks the bridge on the robot and then
   checks the actual iPhone-to-robot UDP connection.
6. Save with **Done**, then use the ordinary remote-control UI.

The default runtime is `sml_navigation_move_base`, using
`source /opt/ros/jazzy/setup.bash`. It must be running and use host networking.
The bridge runs as an additional process inside that container. After a
container or robot restart, start the driver normally and tap **start rosbridge**
again. This version does not install an automatic boot service. Recreating the
container is supported: Start copies the persistent script into it again.

All operations use the local network. Xcode resolves the SSH library at build
time; neither the installed app nor the robot downloads dependencies at runtime.
The robot must already provide Python 3 and the ROS Python message packages used
by its configuration. Additional/custom ROS types require their installed Python
bindings and, where appropriate, an additional workspace source command.

## Editable configuration

- Host, SSH/UDP ports, username, password, runtime container, setup command and
  environment JSON are editable. An empty container selects native ROS on the host.
- Relative topic/service names use the editable namespace. Leading `/` means
  an absolute name.
- Drive JSON replaces the exact string tokens `$forward`, `$sideways`, and
  `$rotation` with numeric joystick values. Rotation keeps the existing app sign.
- Enable/disable/light JSON describes an entire publish or service packet.
  An empty object `{}` disables that action. For light packets, numeric tokens
  `$red`, `$green`, `$blue`, `$brightness`, and `$mode` are supported.
- The setup command is intentionally shell text, executed as the SSH user.
  ROS command bodies are JSON, never shell commands.
- The report includes available nodes, topics, subscribers/QoS, services,
  interface fields/defaults, effective ROS environment and discovery warnings.
  Editing the report adds notes; control behavior comes from the dedicated fields.

SML defaults use `/autonohm/sml_bot/cmd_vel` (`geometry_msgs/msg/Twist`) and
`/autonohm/sml_bot/enable` (`std_srvs/srv/SetBool`, `data: true/false`). Lighting
defaults to disabled. Discovery proposes the SetBool mapping but cannot prove
hardware semantics; it never calls the service to guess its meaning.

Passwords are stored in the device Keychain. SSH host keys use trust on first use
and reject subsequent changes. UDP control follows the existing app's local
network transport; SSH protection applies to setup operations, not UDP packets.

## Validation

Run `python3 -B -m unittest discover -s tests -p 'test_robot_bridge.py' -v` from
the repository root. These checks exercise offline deployment, container fallback,
restart handling, port conflicts and UDP parsing with ROS doubles. Real ROS and
robot hardware still require the on-device workflow above.
