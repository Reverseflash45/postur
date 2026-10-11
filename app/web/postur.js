// Jembatan JavaScript untuk versi web Postur.
//
// - posturPose: MediaPipe Pose Landmarker (33 titik BlazePose, urutan sama
//   dengan ML Kit di Android) yang membaca elemen <video> dari webcam.
// - posturTflite: menjalankan berkas .tflite yang sama dengan aplikasi Android
//   (1D-CNN dan LSTM) lewat TensorFlow.js TFLite.
//
// Pustaka dimuat saat pertama kali dibutuhkan, jadi mode demo tetap ringan.
(function () {
  "use strict";

  var VISI = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.35";
  var MODEL_POSE =
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task";
  var TFJS = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-core@4.22.0/dist/tf-core.min.js";
  var TFJS_CPU = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-cpu@4.22.0/dist/tf-backend-cpu.min.js";
  var TFLITE = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-tflite@0.0.1-alpha.10";

  // ---------------------------------------------------------------- pose
  var pose = null;
  var muatPose = null;
  var delegasi = null;

  async function buatPose() {
    var vision = await import(VISI + "/vision_bundle.mjs");
    var berkas = await vision.FilesetResolver.forVisionTasks(VISI + "/wasm");
    var opsi = function (d) {
      return {
        baseOptions: { modelAssetPath: MODEL_POSE, delegate: d },
        runningMode: "VIDEO",
        numPoses: 1,
        minPoseDetectionConfidence: 0.5,
        minPosePresenceConfidence: 0.5,
        minTrackingConfidence: 0.5,
      };
    };
    try {
      var p = await vision.PoseLandmarker.createFromOptions(berkas, opsi("GPU"));
      delegasi = "gpu";
      return p;
    } catch (e) {
      // Sebagian peramban/laptop tidak punya WebGL2 yang cukup; CPU tetap jalan.
      var c = await vision.PoseLandmarker.createFromOptions(berkas, opsi("CPU"));
      delegasi = "cpu";
      return c;
    }
  }

  window.posturPose = {
    siapkan: function () {
      if (!muatPose) {
        muatPose = buatPose().then(
          function (p) {
            pose = p;
          },
          function (e) {
            muatPose = null;
            throw e;
          },
        );
      }
      return muatPose;
    },
    delegasi: function () {
      return delegasi || "";
    },
    // 99 angka (x, y dalam piksel video; visibilitas 0–1) atau null bila
    // tidak ada orang. ms harus selalu naik.
    deteksi: function (video, ms) {
      if (!pose || video.readyState < 2 || !video.videoWidth) return null;
      var r = pose.detectForVideo(video, ms);
      var lm = r && r.landmarks && r.landmarks[0];
      if (!lm) return null;
      var w = video.videoWidth;
      var h = video.videoHeight;
      var out = new Float64Array(99);
      for (var j = 0; j < 33; j++) {
        var t = lm[j];
        out[3 * j] = t.x * w;
        out[3 * j + 1] = t.y * h;
        out[3 * j + 2] = t.visibility == null ? 1 : t.visibility;
      }
      return out;
    },
  };

  // -------------------------------------------------------------- tflite
  var muatTf = null;

  function skrip(src) {
    return new Promise(function (ok, gagal) {
      var s = document.createElement("script");
      s.src = src;
      s.async = true;
      s.onload = ok;
      s.onerror = function () {
        gagal(new Error("Gagal memuat " + src));
      };
      document.head.appendChild(s);
    });
  }

  function siapkanTf() {
    if (!muatTf) {
      muatTf = (async function () {
        await skrip(TFJS);
        await skrip(TFJS_CPU);
        await skrip(TFLITE + "/dist/tf-tflite.min.js");
        window.tflite.setWasmPath(TFLITE + "/wasm/");
        await window.tf.setBackend("cpu");
      })().catch(function (e) {
        muatTf = null;
        throw e;
      });
    }
    return muatTf;
  }

  window.posturTflite = {
    muat: async function (bytes) {
      await siapkanTf();
      var buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      return window.tflite.loadTFLiteModel(buf, { numThreads: 1 });
    },
    // data: Float32Array berukuran n*k (sudah distandarkan). Hasil: peluang per kelas.
    jalankan: function (model, data, n, k) {
      var tf = window.tf;
      var masuk = tf.tensor(data, [1, n, k], "float32");
      var keluar = model.predict(masuk);
      var t = keluar.dataSync ? keluar : keluar[Object.keys(keluar)[0]];
      var hasil = Float64Array.from(t.dataSync());
      masuk.dispose();
      t.dispose();
      return hasil;
    },
  };
})();
