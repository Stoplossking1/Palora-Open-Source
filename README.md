
### Overview of the New macOS 14.4 Audio Capture API

macOS 14.4 introduces a new CoreAudio API that allows apps to capture audio from other applications or even the entire system, as long as the user grants permission. Apple has not provided much official documentation, and CoreAudio’s low-level design makes it difficult to understand how everything fits together.

This section gives a simple, high-level summary of how the new API works and how you can use it in your own project.
----
You can use this project as a free alternative to [Granola](https://www.granola.ai/) 
----
[Palora Free Alternative to Granola](https://auto-record-meet.lovable.app/)


---

### How It Works (Simplified)

1. **Add the required permission**
   Add `NSAudioCaptureUsageDescription` to your app’s Info.plist. This enables macOS to prompt the user the first time your app tries to capture system or app audio.

2. **Identify what you want to capture**
   You can capture audio from:

   * A specific app (using its process identifier), or
   * The system output device.

   To do this, you translate the target app’s PID or the system device into an `AudioObjectID` using CoreAudio APIs.

3. **Create a CoreAudio tap**
   Next, create a `CATapDescription` using the target’s `AudioObjectID` and use `AudioHardwareCreateProcessTap()` to create the tap.
   The tap exposes the real-time audio data that comes from that process or from the system device.

4. **Build an aggregate device**
   Create an Aggregate Audio Device that includes your tap. This allows your app to receive audio from the tap using a standard device I/O callback.

5. **Prepare for capture**
   Query the tap for its audio format (`kAudioTapPropertyFormat`).
   Use this to set up an `AVAudioFormat`, an `AVAudioPCMBuffer`, and optionally an `AVAudioFile` if you plan to record the audio.

6. **Start capturing**
   Register an IOProc callback with `AudioDeviceCreateIOProcIDWithBlock()`.
   In this callback, read the buffers provided by the tap and write them to your `AVAudioFile` or process them however you need.
   Finally, start the aggregate device using `AudioDeviceStart()` to begin capturing audio.

7. **Stop and clean up**
   When you're done, call `AudioDeviceStop()` and release the tap and aggregate device.

---

### Notes

* The system displays a menu bar indicator while audio capture is active.
* The API is new and may behave differently across devices or under different routing conditions.
* Some parts of the API are still under-documented, so expect to do some testing and validation on your own hardware setups.

---
