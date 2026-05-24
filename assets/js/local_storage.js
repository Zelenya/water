export const getLocalStorageItem = (key) => {
  try {
    return window.localStorage.getItem(key);
  } catch (error) {
    console.warn("localStorage getItem failed:", error);
    return null;
  }
};

export const setLocalStorageItem = (key, value) => {
  try {
    window.localStorage.setItem(key, value);
    return true;
  } catch (error) {
    console.warn("localStorage setItem failed:", error);
    return false;
  }
};

export const removeLocalStorageItem = (key) => {
  try {
    window.localStorage.removeItem(key);
  } catch (error) {
    console.warn("localStorage removeItem failed:", error);
  }
};
