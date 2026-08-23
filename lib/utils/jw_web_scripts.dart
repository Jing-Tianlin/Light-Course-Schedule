import '../config/jw_config.dart';

/// 融合门户 / 教务 WebView 导入所需的 JavaScript 脚本集合。
class JwWebScripts {
  JwWebScripts._();

  /// 覆盖 navigator.userAgent，防止前端检测到手机版。
  static const String userAgentOverride = '''
    (function() {
      const desktopUa = '${JwConfig.desktopUserAgent}';
      Object.defineProperty(navigator, 'userAgent', {
        get: function() { return desktopUa; },
        configurable: true
      });
      Object.defineProperty(navigator, 'appVersion', {
        get: function() { return '5.0 (Windows NT 10.0; Win64; x64)'; },
        configurable: true
      });
      Object.defineProperty(navigator, 'platform', {
        get: function() { return 'Win32'; },
        configurable: true
      });
      if (navigator.userAgentData) {
        try {
          Object.defineProperty(navigator, 'userAgentData', {
            get: function() { return null; },
            configurable: true
          });
        } catch (_) {}
      }
    })();
  ''';

  /// 调整 viewport，让桌面页面横向完整显示，同时允许缩放。
  static const String fitViewport = '''
    (function() {
      var deviceW = window.screen.width || window.innerWidth || 360;
      var pageW = Math.max(
        document.documentElement.scrollWidth || 0,
        document.body.scrollWidth || 0,
        document.documentElement.clientWidth || 0,
        document.body.clientWidth || 0,
        1200
      );
      var scale = deviceW / pageW;
      if (scale > 1) scale = 1;
      if (scale < 0.25) scale = 0.25;
      var meta = document.querySelector('meta[name=viewport]');
      if (!meta) {
        meta = document.createElement('meta');
        meta.name = 'viewport';
        document.head.appendChild(meta);
      }
      meta.content = 'width=' + pageW + ', initial-scale=' + scale +
                     ', minimum-scale=0.25, maximum-scale=5, user-scalable=yes';
    })();
  ''';

  /// 从页面文本中识别学号。
  static const String extractStudentId = '''
    (function() {
      var text = document.body ? document.body.innerText : '';
      if (!text) text = document.documentElement ? document.documentElement.innerText : '';
      var m = text.match(/[(（]\\s*(\\d{10,15})\\s*[)）]/);
      if (m) return m[1];
      m = text.match(/\\b\\d{10,15}\\b/);
      return m ? m[0] : '';
    })();
  ''';

  /// 从课表页面（含 iframe）读取当前选中的学期 ID。
  static const String extractSemesterId = r'''
    (function() {
      function findId(doc) {
        if (!doc || !doc.documentElement) return null;
        var sel = doc.querySelector('#semester, [name="semester"], select[id*="semester"], select[name*="semester"]');
        if (sel && sel.value && /^\d+$/.test(sel.value)) return sel.value;
        var html = doc.documentElement.outerHTML || '';
        var m = html.match(/semesterId["']?\s*[:=]\s*["']?(\d+)/i);
        if (m) return m[1];
        m = html.match(/\/semester\/(\d+)\/print-data/i);
        if (m) return m[1];
        m = html.match(/<option[^>]*value=["'](\d+)["'][^>]*selected[^>]*>/i);
        if (m) return m[1];
        return null;
      }
      var id = findId(document);
      if (id) return id;
      var iframes = document.querySelectorAll('iframe');
      for (var i = 0; i < iframes.length; i++) {
        try {
          id = findId(iframes[i].contentDocument);
          if (id) return id;
        } catch (_) {}
      }
      return '';
    })();
  ''';

  /// 在当前页面以同步 XHR 请求新教务 `print-data` 接口。
  static String fetchPrintData(String semesterId) => '''
    (function(semesterId) {
      var url = '/student/for-std/course-table/semester/' + semesterId +
                '/print-data?semesterId=' + semesterId + '&hasExperiment=true';
      var xhr = new XMLHttpRequest();
      xhr.open('GET', url, false);
      xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
      xhr.setRequestHeader('Accept', 'application/json, text/javascript, */*; q=0.01');
      xhr.send(null);
      if (xhr.status !== 200) {
        throw new Error('HTTP ' + xhr.status + ' ' + xhr.statusText);
      }
      return xhr.responseText || '{}';
    })('$semesterId');
  ''';

  /// 获取当前页面完整 HTML。
  static const String pageHtml = 'document.documentElement.outerHTML';
}
