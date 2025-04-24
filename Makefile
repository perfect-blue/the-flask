
NETWORK_NAME = "the-network"
STATION_ENV = "envs/.dotty.env"
DB_ENV = "envs/.dotty.env"
DB_PORT = 5432
testr := ""
USER := ubuntu
MODULE_NAME := ""
MODULE_IMAGE := module
MODULE_CMD := ""
SWAGGER_UI_NAME := swaggerui


build-module:
	# make precommit
	# ensure SSH exists on the local machine
	which ssh-agent || (apt-get update -y && apt-get install openssh-client -y)
	# invoke a SSH connection
	eval $$(ssh-agent -s) && cat .ssh/gitlab_key | tr -d '\r' | ssh-add - \
	&& DOCKER_BUILDKIT=1 docker build \
		--cache-from station \
		--build-arg COMMIT_SHA=$$(git rev-parse HEAD) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-f dockerfiles/station.Dockerfile \
		--ssh default \
		-t $(MODULE_IMAGE) .

setup-pre-module:
	make build-module
	make clean
	docker network create $(NETWORK_NAME) || true
	make up-test-db
	docker volume create TmpData || true
	# docker rm -fv ${SWAGGER_UI_NAME} || true

setup-module:
	make run-station STATION_NAME=station-test \
		STATION_CMD="gunicorn --preload --config gunicorn.conf.py 'app.factory:create_app(init=False)'"
	# uncomment to debug startup issue
	# docker logs -f station-test

setup-test:
	make setup-pre-module
	make setup-module
	make prune

setup-all:
	make setup-test
	make up-other-dbs

clean:
	docker rm -fv test-db || true
	docker rm -fv redis || true
	docker volume rm -f TmpData || true

prune:
	docker system prune -f --volumes

test:
	make setup-all
	docker exec -it station-test python3.9 -m unittest \
		discover -v -p *_test.py -k ${testr} \
		# > res.log 2>&1
	# uncomment previous line to store test result into res.log

# Database related
check-test-db:
	docker exec -it test-db psql -U test-db

up-test-db:
	docker run -d \
		--network $(NETWORK_NAME) \
		--name test-db \
		--env-file ${DB_ENV} \
		-p 5434:${POSTGRES_PORT} \
		--rm postgres:11-alpine s