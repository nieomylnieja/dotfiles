local-secrets:
	@grep -ve "^#.*" secrets.env  > secrets.local.env
