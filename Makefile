local-secrets:
	@grep -ve "^#.*" secrets  > secrets.local
