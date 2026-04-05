const path = require('path');

module.exports = function (api) {
  api.cache(true);

  const routerEntry = require.resolve('expo-router/entry');
  const appRoot = path.relative(path.dirname(routerEntry), path.join(__dirname, 'app'));

  return {
    presets: ['babel-preset-expo'],
    plugins: [
      function inlineExpoRouterEnv({ types: t }) {
        return {
          name: 'inline-expo-router-env',
          visitor: {
            MemberExpression(memberPath) {
              if (!memberPath.get('object').matchesPattern('process.env')) {
                return;
              }

              const key = memberPath.toComputedKey();
              if (!t.isStringLiteral(key)) return;

              if (key.value === 'EXPO_ROUTER_APP_ROOT') {
                memberPath.replaceWith(t.stringLiteral(appRoot));
              }

              if (key.value === 'EXPO_ROUTER_IMPORT_MODE') {
                memberPath.replaceWith(t.stringLiteral('sync'));
              }
            },
          },
        };
      },
    ],
  };
};
