# gha-docker-service-ssh

GitHub Action to manage the deployment of a Docker service over SSH.

## Usage

```yaml
steps:
  - name: Deploy Docker Service
    uses: albr21/gha-docker-service-ssh@v1
    with:
      mode: full
      image-name: my-docker-image
      image-tag: latest
      user: myuser
      host: myserver.com
      remote-path: /home/myuser/docker-service
      port-mapping: "8080:80,8443:443"
      ssh-key: ${{ secrets.SSH_KEY }}
      ssh-known-hosts: ${{ secrets.SSH_KNOWN_HOSTS }}
      environment-variables: "ENV_VAR1=value1,ENV_VAR2=value2"
      volume-mapping: "/host/path:/container/path"
      run-command: "echo Hello from inside the container"
      command-line-interpreter: bash
```

## Contributing

Check out the [CONTRIBUTING](CONTRIBUTING.md) file for guidelines on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
