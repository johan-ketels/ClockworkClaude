.PHONY: app clean

app:
	VERSION=$${VERSION:-0.1.0} bash scripts/build-app.sh

clean:
	rm -rf build/ .build/
