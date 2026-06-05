module.exports = {
  apps: [
    {
      name: 'xiaotai-backend',
      cwd: '/www/wwwroot/xiaotai/xiaotai_server/backend',
      script: 'dist/main.js',
      instances: 1,
      exec_mode: 'fork',
      env: {
        NODE_ENV: 'production',
      },
      max_memory_restart: '512M',
      out_file: '/www/wwwlogs/xiaotai-backend.out.log',
      error_file: '/www/wwwlogs/xiaotai-backend.err.log',
      time: true,
    },
  ],
};
