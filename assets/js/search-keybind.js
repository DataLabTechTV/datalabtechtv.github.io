document.addEventListener("keydown", function (event) {
    // Check for ctrl+k or ⌘+k (Mac)
    const isMac = navigator.platform.toUpperCase().indexOf("MAC") >= 0;
    const isCtrlK = (!isMac && event.ctrlKey && event.key == "k");
    const isCmdK = (isMac && event.metaKey && event.key == "k");

    if (isCtrlK || isCmdK) {
        event.preventDefault();
        displaySearch();
    }
});
