// Convert blob URL to Base64
(async function (blobUrl) {
  const blob = await fetch(blobUrl).then((response) => response.blob());
  const reader = new FileReader();
  reader.onloadend = function () {
    const base64data = reader.result.split(",")[1];
    const mimeType = blob.type;
    window.flutter_inappwebview.callHandler(
      "blobToBase64",
      base64data,
      mimeType
    );
  };
  reader.readAsDataURL(blob);
})("blobUrlPlaceholder");
