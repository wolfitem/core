{
  cache(settings={})::
    {
      name: 'restore',
      image: 'plugins/s3-cache:1',
      pull: 'always',
      settings: {
        endpoint: {
          from_secret: 'cache_s3_endpoint'
        },
        access_key: {
          from_secret: 'cache_s3_access_key'
        },
        secret_key: {
          from_secret: 'cache_s3_secret_key'
        },
      } + settings,
      when: {
        instance: [
          'drone.owncloud.com',
        ],
      } + if std.objectHas(settings, 'restore') then {} else { event: ['push'] },
    },

  yarn(image='owncloudci/php:7.1')::
    {
      name: 'yarn',
      image: image,
      pull: 'always',
      environment: {
        NPM_CONFIG_CACHE: '/drone/src/.cache/npm',
        YARN_CACHE_FOLDER: '/drone/src/.cache/yarn',
        bower_storage__packages: '/drone/src/.cache/bower',
      },
      commands: [
        'make install-nodejs-deps',
      ],
    },

  composer(image='owncloudci/php:7.1')::
    {
      name: 'composer',
      image: image,
      pull: 'always',
      environment: {
        COMPOSER_HOME: '/drone/src/.cache/composer',
      },
      commands: [
        'make install-composer-deps',
      ],
    },

  vendorbin(image='owncloudci/php:7.1')::
    {
      name: 'vendorbin',
      image: image,
      pull: 'always',
      environment: {
        COMPOSER_HOME: '/drone/src/.cache/composer',
      },
      commands: [
        'make vendor-bin-deps',
      ],
    },

  install(trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'install-dependencies',
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:7.1'),
        $.vendorbin(image='owncloudci/php:7.1'),
        $.yarn(image='owncloudci/php:7.1'),
        $.cache({ rebuild: true, mount: ['.cache'] }),
        $.cache({ flush: true, flush_age: 14 }),
      ],
      trigger: trigger,
      depends_on: depends_on,
    },

  standard(trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'coding-standard',
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:7.1'),
        $.vendorbin(image='owncloudci/php:7.1'),
        $.yarn(image='owncloudci/php:7.1'),
        {
          name: 'test',
          image: 'owncloudci/php:7.3',
          pull: 'always',
          commands: [
            'make test-php-style',
          ],
        },
      ],
      trigger: trigger,
      depends_on: depends_on,
    },

  phan(php='', trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'phan-php' + php,
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:' + php),
        $.vendorbin(image='owncloudci/php:' + php),
        $.yarn(image='owncloudci/php:' + php),
        {
          name: 'test',
          image: 'owncloudci/php:' + php,
          pull: 'always',
          commands: [
            'make test-php-phan',
          ],
        },
      ],
      trigger: trigger,
      depends_on: depends_on,
    },

  stan(php='', trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'stan-php' + php,
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:' + php),
        $.vendorbin(image='owncloudci/php:' + php),
        $.yarn(image='owncloudci/php:' + php),
        {
          name: 'test',
          image: 'owncloudci/php:' + php,
          pull: 'always',
          commands: [
            'make test-php-phpstan',
          ],
        },
      ],
      trigger: trigger,
      depends_on: depends_on
    },

  javascript(trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'test-javascript',
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:7.1'),
        $.vendorbin(image='owncloudci/php:7.1'),
        $.yarn(image='owncloudci/php:7.1'),
        {
          name: 'test',
          image: 'owncloudci/php:7.1',
          pull: 'always',
          commands: [
            'make test-js',
          ],
        },
        {
          name: 'codecov',
          image: 'plugins/codecov:2',
          pull: 'always',
          environment: {
            CODECOV_TOKEN: {
              from_secret: 'codecov_token',
            },
          },
          settings: {
            flags: [
              'javascript',
            ],
            paths: [
              'tests/output/coverage',
            ],
            files: [
              '*.xml',
            ],
          },
        },
      ],
      trigger: trigger,
      depends_on: depends_on,
    },

  phpunit(php='', db='', coverage=false, external='', object='', trigger={}, depends_on=[])::
    local database_split = std.split(db, ':');

    local database_name = database_split[0];
    local database_version = database_split[1];

    {
      kind: 'pipeline',
      name: 'phpunit-php' + php + '-' + std.join('', database_split),
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:7.1'),
        $.vendorbin(image='owncloudci/php:7.1'),
        $.yarn(image='owncloudci/php:7.1'),
        {
          name: 'test',
          image: 'owncloudci/php:' + php,
          pull: 'always',
          commands: [

          ],
        },
      ],
      trigger: trigger,
      depends_on: depends_on,
    },

  behat(browser='', suite='', filter='', num='', trigger={}, depends_on=[])::
    {
      kind: 'pipeline',
      name: 'behat',
      platform: {
        os: 'linux',
        arch: 'amd64',
      },
      steps: [
        $.cache({ restore: true }),
        $.composer(image='owncloudci/php:7.1'),
        $.vendorbin(image='owncloudci/php:7.1'),
        $.yarn(image='owncloudci/php:7.1'),
        {
          name: 'test',
          image: 'owncloudci/php:7.1',
          pull: 'always',
          commands: [

          ],
        },
      ],
      trigger: trigger,
      depends_on: depends_on,
    },
}
