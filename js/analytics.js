// Google Analytics (GA4) — loaded once, referenced from every page.
// To change the property, edit the measurement ID here only.
(function () {
  var MEASUREMENT_ID = 'G-9DZ32W5LSJ';

  var loader = document.createElement('script');
  loader.async = true;
  loader.src = 'https://www.googletagmanager.com/gtag/js?id=' + MEASUREMENT_ID;
  document.head.appendChild(loader);

  window.dataLayer = window.dataLayer || [];
  function gtag() { dataLayer.push(arguments); }
  window.gtag = gtag;
  gtag('js', new Date());
  gtag('config', MEASUREMENT_ID);
})();
