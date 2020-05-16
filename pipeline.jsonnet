local source = 'git';
local container = 'dev-container';

local GitResource(name, repository, branch = 'master') = {
  name: name,
  type: 'git',
  source: {
    uri: repository,
    branch: branch
  },
};

local DockerResource(name, repository, tag = null, allow_insecure = false) = {
  name: name,
  type: 'docker-image',
  source: {
    repository: repository,
    tag: if tag != null then tag else 'latest',
  } + (
    if allow_insecure then { insecure_registries: [std.split(repository, '/')[0]]} else {}
  ),
};

local resources = [
  GitResource(source, 'https://github.com/sirech/example-concourse-pipeline.git'),
  DockerResource(container, 'registry:5000/dev-container', allow_insecure = true),
  DockerResource('serverspec-container', 'sirech/dind-ruby', tag = '2.6.3'),
];

local common_params() = {
  CI: true
};

local docker_params(name) = {
  tag: '%s/.git/HEAD' % [name],
  tag_as_latest: true,
  cache: true,
  cache_tag: 'latest'
};

local Get(name, dependencies = []) = {
  get: name,
  trigger: true,
  passed: dependencies
};

local Parallel(tasks) = {
  in_parallel: tasks
};

local Inputs(dependencies = []) = Parallel([
  Get(source, dependencies = dependencies),
  Get(container, dependencies = dependencies),
]);

local Task(name, file, image = container, params = {}) = {
  task: name,
  image: image,
  params: common_params() + params,
  file: '%s/pipeline/tasks/%s/task.yml' % [source, file]
};

local Job(name, plan) = {
  name: name,
  serial: true,
  plan: plan
};

local jobs = [
  Job('prepare', [
    Get(source),
    Parallel([
      Get('serverspec-container'),
      {
        put: 'dev-container',
        params: docker_params(source) + {
          build: source,
          dockerfile: '%s/Dockerfile.build' % source
        }
      }
    ]),
    Task('pipeline', 'update_pipeline', params = {
      CONCOURSE_USER: 'test',
      CONCOURSE_PASSWORD: '((concourse_password))',
      CONCOURSE_URL: 'http://web:8080'
    })
  ]),

  Job('lint', [
    Inputs(['prepare']),
    Parallel(
      [Task('lint-%s' % lang, 'linter', params = { TARGET: lang}) for lang in ['sh', 'js', 'css', 'docker']]
    )
  ]),

  Job('test', [
    Inputs(['prepare']),
    Task('test-js', 'tests', params = { TARGET: 'js' })
  ]),

  Job('build', [
    Inputs(['lint', 'test']),
    Task('build-dev', 'build')
  ])
];

{
  resources: resources,
  jobs: jobs
}
