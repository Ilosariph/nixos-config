{ ... }:
# Workarounds for upstream build failures on evo. Remove once fixed upstream.
{
  nixpkgs.overlays = [
    (_: prev: {
      # GCC 16.2 lto1 ICEs ("stack smashing detected" in rtx_properties::try_to_add_src)
      # linking the unit test binary onnxruntime_ep_graph_test. doCheck = false also
      # sets onnxruntime_BUILD_UNIT_TESTS off. python onnxruntime (comfyui) overrides
      # pkgs.onnxruntime, so it inherits this.
      onnxruntime = prev.onnxruntime.overrideAttrs { doCheck = false; };

      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pyPrev: {
          # open-webui dep: test_word_embeddings_encode_empty_tokens_batch_invariance[1-lstm]
          # fails "Tensor-likes are not close!" (float tolerance).
          sentence-transformers = pyPrev.sentence-transformers.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_word_embeddings_encode_empty_tokens_batch_invariance"
            ];
          });
        })
      ];
    })
  ];
}
