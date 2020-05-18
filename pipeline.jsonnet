local source = 'git';
local container = 'dev-container';

local concourse = import 'concourse.libsonnet';

local docker_params(name) = {
  tag: '%s/.git/HEAD' % [name],
  tag_as_latest: true,
  cache: true,
  cache_tag: 'latest'
};

local Inputs(dependencies = []) = concourse.Parallel(
  [concourse.Get(s, dependencies = dependencies) for s in [source, container]]
);

local Task(name, file = name, image = container, params = {}) = {
  task: name,
  image: image,
  params: { CI: true } + params,
  file: '%s/pipeline/tasks/%s/task.yml' % [source, file]
};

local resources = [
  concourse.GitResource(source, 'https://github.com/sirech/example-concourse-pipeline.git'),
  concourse.DockerResource(container, 'registry:5000/dev-container', allow_insecure = true),
  concourse.DockerResource('serverspec-container', 'sirech/dind-ruby', tag = '2.6.3'),
];

local jobs = [
  concourse.Job('prepare', plan = [
    concourse.Get(source),
    concourse.Parallel([
      concourse.Get('serverspec-container'),
      {
        put: 'dev-container',
        params: docker_params(source) + {
          build: source,
          dockerfile: '%s/Dockerfile.build' % source
        }
      }
    ]),
    Task('update_pipeline', params = {
      CONCOURSE_USER: 'test',
      CONCOURSE_PASSWORD: 'test',
      CONCOURSE_URL: 'http://web:8080'
    })
  ]),

  concourse.Job('lint', plan = [
    Inputs('prepare'),
    concourse.Parallel(
      [Task('lint-%s' % lang, 'linter', params = { TARGET: lang }) for lang in ['sh', 'js', 'css', 'docker']]
    )
  ]),

  concourse.Job('test', plan = [
    Inputs('prepare'),
    Task('test-js', 'tests', params = { TARGET: 'js' })
  ]),

  concourse.Job('build', plan = [
    Inputs(['lint', 'test']),
    Task('build')
  ])
];

{
  "pipeline.generated.json": {
    resources: resources,
    jobs: jobs
  }
} + {
  ['pipeline/tasks/%s/task.json' % [task]]: concourse.FileTask('pipeline/tasks/%s/task.sh' % [task], inputs = source, caches = '%s/node_modules' % [source]) for task in ['build', 'linter', 'tests']
}
