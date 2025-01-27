DOCKER    = docker

BASE_REPO = cloudflare/quiche
BASE_TAG  = latest

QNS_REPO  = cloudflare/quiche-qns
QNS_TAG   = latest

FUZZ_REPO = cloudflare.mayhem.security:5000/protocols/quiche-libfuzzer
FUZZ_TAG  = latest

docker-build: docker-base docker-qns

# build quiche-apps only
.PHONY: build-apps
build-apps:
	cargo build --package=quiche_apps

# build base image
.PHONY: docker-base
docker-base: Dockerfile
	$(DOCKER) build --target quiche-base -t $(BASE_REPO):$(BASE_TAG) .

# build qns image
.PHONY: docker-qns
docker-qns: Dockerfile apps/run_endpoint.sh
	$(DOCKER) build --target quiche-qns -t $(QNS_REPO):$(QNS_TAG) .

.PHONY: docker-publish
docker-publish:
	$(DOCKER) push $(BASE_REPO):$(BASE_TAG)
	$(DOCKER) push $(QNS_REPO):$(QNS_TAG)

# build fuzzers
.PHONY: build-fuzz
build-fuzz:
	cargo +nightly fuzz build --release --debug-assertions packet_recv_client
	cargo +nightly fuzz build --release --debug-assertions packet_recv_server
	cargo +nightly fuzz build --release --debug-assertions qpack_decode

# build fuzzing image
.PHONY: docker-fuzz
docker-fuzz:
	$(DOCKER) build -f fuzz/Dockerfile --target quiche-libfuzzer --tag $(FUZZ_REPO):$(FUZZ_TAG) .

.PHONY: docker-fuzz-publish
docker-fuzz-publish:
	$(DOCKER) push $(FUZZ_REPO):$(FUZZ_TAG)

.PHONY: clean
clean:
	@for id in `$(DOCKER) images -q $(BASE_REPO)` `$(DOCKER) images -q $(QNS_REPO)` `$(DOCKER) images -q $(FUZZ_REPO)`; do \
		echo ">> Removing $$id"; \
		$(DOCKER) rmi -f $$id; \
	done


### Experiments

experiment_1_10:
	sudo rm /vagrant/quicopsat-stage2/quiche_latest/logs/exp1/10/*
	sudo python /vagrant/quicopsat-stage2/quiche_latest/mn_script.py /vagrant/quicopsat-stage2/quiche_latest/logs/exp1/10 10

experiment_1_100:
	sudo rm /vagrant/quicopsat-stage2/quiche_latest/logs/exp1/100/*
	sudo python /vagrant/quicopsat-stage2/quiche_latest/mn_script.py /vagrant/quicopsat-stage2/quiche_latest/logs/exp1/100 100


experiment_1:
	echo "Testing 1MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/1 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 1MB NO CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/1/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/2 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB no CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/2/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 5MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/5 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 5MB NO CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/5/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 20MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/20 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 20MB NO CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/20/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 50MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/50 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 50MB NO CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/50/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 100MB CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 100MB NO CR"
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


experiment_1_high_IW:
	echo "Testing 1MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/1/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/1/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/2/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/2/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 5MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/5/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/5/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/10/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/10/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 20MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/20/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/20/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 50MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/50/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/50/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 100MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000  --initial-cwnd-packets 1400 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


aux:
	echo "Testing 100MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/100/high_iw && unset PREVIOUS_CWND_BYTES && unset PREVIOUS_RTT  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..3} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

fq_link:
	echo "Testing 20MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/fq_link
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp1/fq_link && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


fq_fq_codel_link:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq_codel
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel_intf/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel_intf/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_fq_codel_link_no_pacing:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq_codel
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf/no_pacing
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf/no_pacing/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_codel_intf/no_pacing/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 --disable-pacing &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel_intf/no_pacing/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel_intf/no_pacing/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump

fq_fq_link:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_intf/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_intf/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_fq_link_no_pacing:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf/no_pacing
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf/no_pacing/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq/fq_intf/no_pacing/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 --disable-pacing &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_intf/no_pacing/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_intf/no_pacing/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_codel_fq_codel_link:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq_codel
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel/fq_codel_intf/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel/fq_codel_intf/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_codel_fq_codel_link_no_pacing:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq_codel
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf/no_pacing
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf/no_pacing/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_codel_intf/no_pacing/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 --disable-pacing &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel/fq_codel_intf/no_pacing/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel/fq_codel_intf/no_pacing/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_codel_fq_link:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel/fq_intf/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel/fq_intf/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump


fq_codel_fq_link_no_pacing:
	echo "Testing with FQ Codel interface link"
	sudo tc qdisc del dev eth0 root
	sudo tc qdisc add dev eth0 root fq
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf/no_pacing
	sudo tcpdump -i eth0 port 4433 -w /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf/no_pacing/server.pcap &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/pacing_experiments/fq_codel/fq_intf/no_pacing/ && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 300000000 --disable-pacing &
	@ssh simulator2 "mkdir -p /home/mihail/logs/fq_codel/fq_intf/no_pacing/"
	@ssh simulator2 "export QLOGDIR=/home/mihail/logs/fq_codel/fq_intf/no_pacing/ && cd quiche && /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 300000000 > /dev/null && sleep 2"
	sudo killall quiche-server
	sudo killall tcpdump



experiment_2:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"
	sleep 3

	echo "Testing 1MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 1MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 5MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 5MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 20MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 20MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 50MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 50MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 100MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 100MB NO CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100/no_cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 25 600 && sudo ipfw pipe list"
	sleep 3

experiment_2_high_IW:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"
	sleep 10

	echo "Testing 1MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/1/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/1M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 2MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/2M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 5MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/5/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/5M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 20MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/20/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/20M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 50MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/50/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/50M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 100MB high_IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/100/high_iw && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 25 600 && sudo ipfw pipe list"
	sleep 3

exp_2_latest:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"

	echo "Testing 10MB high_IW"
	mkdir -p /mnt/logs/remote/exp2/high_iw/10
	export QLOGDIR=/mnt/logs/remote/exp2/high_iw/10 && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-data 300000000 --max-stream-data 300000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB CR"
	mkdir -p /mnt/logs/remote/exp2/cr/10
	export QLOGDIR=/mnt/logs/remote/exp2/cr/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-data 300000000 --max-stream-data 300000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB Cubic"
	mkdir -p /mnt/logs/remote/exp2/cubic/10
	export QLOGDIR=/mnt/logs/remote/exp2/cubic/10 && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-data 300000000 --max-stream-data 300000000 > /dev/null && sleep 2 ; done"
	killall quiche-server && sleep 5


exp_4:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"

	echo "Testing 10MB high_IW"
	mkdir -p /mnt/logs/remote/exp4/high_iw/10
	export QLOGDIR=/mnt/logs/remote/exp4/high_iw/10 && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	export QLOGDIR=/mnt/logs/remote/exp4/high_iw/10 && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do python3 exp_4.py && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB CR"
	mkdir -p /mnt/logs/remote/exp4/cr/10
	export QLOGDIR=/mnt/logs/remote/exp4/cr/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	export QLOGDIR=/mnt/logs/remote/exp4/cr/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do python3 exp_4.py && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB Cubic"
	mkdir -p /mnt/logs/remote/exp4/cubic/10
	export QLOGDIR=/mnt/logs/remote/exp4/cubic/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	export QLOGDIR=/mnt/logs/remote/exp4/cubic/10 && unset PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-data 300000000 --max-stream-data 300000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..20} ; do python3 exp_4.py && sleep 2 ; done"
	killall quiche-server && sleep 5


exp_2_short:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"
	sleep 3

	# echo "Testing 10MB CR"
	# mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/10
	# export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/10 && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	# @ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	# killall quiche-server && sleep 5

	# echo "Testing 10MB NO CR"
	# mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/10/no_cr
	# export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/2/10/no_cr && unset PREVIOUS_CWND_BYTES && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	# @ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 2 ; done"
	# killall quiche-server && sleep 5

	echo "Testing 10MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/3/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp2/10/3/high_iw && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/10M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 30 ; done"
	killall quiche-server && sleep 5

	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 25 600 && sudo ipfw pipe list"
	sleep 3

experiment_3:
	echo "Testing 10MB CR"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5

	echo "Testing 10MB High IW"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/high_iw && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/high_iw && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1400 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5
	

	echo "Testing 10MB Cubic"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cubic
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cubic && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000&
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/10_1/cubic && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5


	echo "Testing 100MB Cubic"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/100_1/cubic
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/100_1/cubic && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/100_1/cubic && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5


exp_3_cr:
	echo "Starting long flow experiment"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5


exp_3_high_IW:
	echo "Starting long flow experiment"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/high_iw
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/high_iw && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	sleep 3 && export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/high_iw && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --initial-cwnd-packets 1390 &
	@ssh simulator2 "cd quiche &&  for i in {1..6} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5

# TODO
exp_3_cubic:
	echo "Starting long flow experiment"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/long/cr && export PREVIOUS_CWND_BYTES=1875000 && export PREVIOUS_RTT=600  && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..10} ; do python3 exp_3.py && sleep 2 ; done"
	killall quiche-server && sleep 5


cubic_test:
	echo "Testing 100MB Cubic"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/test/cubic/tracker
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/test/cubic/tracker && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4430 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/test/cubic/tracker && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do python3 cubic_test.py && sleep 2 ; done"
	killall quiche-server && sleep 5

cubic_test_no_pacing:
	echo "Testing 100MB Cubic"
	mkdir -p /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/test/cubic/no_pacing
	export QLOGDIR=/home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/logs/remote/exp3/test/cubic/no_pacing && cargo run -F boring --bin quiche-server -- --listen 144.76.191.136:4433 --root /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_q/ --key apps/src/bin/cert.key --cert apps/src/bin/cert.crt --max-stream-data 10000000 --disable-pacing &
	@ssh simulator2 "cd quiche &&  for i in {1..1} ; do /home/mihail/.cargo/bin/cargo run --bin quiche-client -- https://144.76.191.136:4433/100M.html --no-verify --max-stream-data 10000000 > /dev/null && sleep 5 ; done"
	killall quiche-server && sleep 5


# Experiments
TRANSFER_SIZES = 020 050 0100 0200 0500 1 2 5 10 20 50

EXP_ROOT=/mnt/logs/new

new_exp_1: config_high_link ${EXP_ROOT}/exp1/cubic_logs_done ${EXP_ROOT}/exp1/cr_logs_done ${EXP_ROOT}/exp1/high_IW_logs_done ${EXP_ROOT}/exp1/IW_30_logs_done

${EXP_ROOT}/exp1/cubic_logs_done: /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/experiment_driver.py
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py cubic.json ${QLOG_ROOT}/cubic/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}


${EXP_ROOT}/exp1/cr_logs_done: /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/experiment_driver.py
	echo "Starting simple CR experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py server_cr.json ${QLOG_ROOT}/cr/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}


${EXP_ROOT}/exp1/high_IW_logs_done: /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/experiment_driver.py
	echo "Starting simple High IW experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py high_iw.json ${QLOG_ROOT}/high_iw/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}

${EXP_ROOT}/exp1/IW_30_logs_done: /home/mihail/quicoptsat/emulation/quicopsat-stage2/quiche_latest/experiment_driver.py
	echo "Starting simple IW=30 experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py iw_30.json ${QLOG_ROOT}/iw_30/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}


new_exp_2: config_low_link ${EXP_ROOT}/exp2/cubic_logs_done ${EXP_ROOT}/exp2/cr_logs_done ${EXP_ROOT}/exp2/high_IW_logs_done ${EXP_ROOT}/exp2/IW_30_logs_done

config_low_link:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 2 600 && sudo ipfw pipe list"
	sleep 3

${EXP_ROOT}/exp2/cubic_logs_done:
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py cubic.json ${QLOG_ROOT}/cubic/$${transfer_size} $${run} $${transfer_size}; \
			skeep 3; \
		done \
	done

	touch ${@}


${EXP_ROOT}/exp2/cr_logs_done:
	echo "Starting simple CR experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py server_cr.json ${QLOG_ROOT}/cr/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}


${EXP_ROOT}/exp2/high_IW_logs_done:
	echo "Starting simple High IW experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py high_iw.json ${QLOG_ROOT}/high_iw/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}


${EXP_ROOT}/exp2/IW_30_logs_done:
	echo "Starting simple IW=30 experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for transfer_size in ${TRANSFER_SIZES} ; do \
		for run in $(shell seq 1 10) ; do \
			python3 experiment_driver.py iw_30.json ${QLOG_ROOT}/iw_30/$${transfer_size} $${run} $${transfer_size}; \
			sleep 3; \
		done \
	done

	touch ${@}

new_exp_3: config_high_link ${EXP_ROOT}/exp3/cubic_logs_done ${EXP_ROOT}/exp3/cr_logs_done ${EXP_ROOT}/exp3/high_IW_logs_done ${EXP_ROOT}/exp3/IW_30_logs_done

${EXP_ROOT}/background/25Mbps/background_done: config_high_link
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver.py cubic.json ${QLOG_ROOT}/100 $${run} 100; \
		sleep 3; \
	done

	touch ${@}

${EXP_ROOT}/background/2Mbps/background_done: config_low_link
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver.py cubic.json ${QLOG_ROOT}/100 $${run} 100; \
		sleep 3; \
	done

	touch ${@}

config_high_link:
	@cat /home/mihail/dummynetpwd | ssh -tt dummynetbox "sudo python3 config_pipes.py 25 600 && sudo ipfw pipe list"
	sleep 3

${EXP_ROOT}/exp3/cubic_logs_done:
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py cubic.json ${QLOG_ROOT}/cubic/10 $${run}; \
	done

	touch ${@}

${EXP_ROOT}/exp3/cr_logs_done:
	echo "Starting CR cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py server_cr.json ${QLOG_ROOT}/cr/10 $${run}; \
	done

	touch ${@}

${EXP_ROOT}/exp3/high_IW_logs_done:
	echo "Starting High IW cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py high_iw.json ${QLOG_ROOT}/high_IW/10 $${run}; \
	done

	touch ${@}

${EXP_ROOT}/exp3/IW_700_logs_done:
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py iw_700.json ${QLOG_ROOT}/iw_700/10 $${run}; \
	done

	touch ${@}

${EXP_ROOT}/exp3/IW_30_logs_done:
	echo "Starting IW=30 cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py iw_30.json ${QLOG_ROOT}/IW_30/10 $${run}; \
	done

	touch ${@}


new_exp_4: config_low_link ${EXP_ROOT}/exp4/cubic_logs_done ${EXP_ROOT}/exp4/cr_logs_done ${EXP_ROOT}/exp4/high_IW_logs_done ${EXP_ROOT}/exp4/IW_30_logs_done


${EXP_ROOT}/exp4/cubic_logs_done:
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py cubic.json ${QLOG_ROOT}/cubic/10 $${run}; \
	done

	touch ${@}


${EXP_ROOT}/exp4/cr_logs_done:
	echo "Starting CR cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py server_cr.json ${QLOG_ROOT}/cr/10 $${run}; \
	done

	touch ${@}


${EXP_ROOT}/exp4/high_IW_logs_done:
	echo "Starting High IW cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py high_iw.json ${QLOG_ROOT}/high_IW/10 $${run}; \
	done

	touch ${@}

${EXP_ROOT}/exp4/IW_700_logs_done:
	echo "Starting simple Cubic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py iw_700.json ${QLOG_ROOT}/iw_700/10 $${run}; \
	done

	touch ${@}


${EXP_ROOT}/exp4/IW_30_logs_done:
	echo "Starting IW=30 cross traffic experiment"
	$(eval QLOG_ROOT := $(shell dirname ${@}))
	mkdir -p ${QLOG_ROOT}

	for run in $(shell seq 1 10) ; do \
		python3 experiment_driver_cross.py iw_30.json ${QLOG_ROOT}/IW_30/10 $${run}; \
	done

	touch ${@}


# Figures

/mnt/parsed/exp1/FCT_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_FCT_pcap.py /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/helpers/get_partial_completion_offset.py ${EXP_ROOT}/exp1/cubic_logs_done ${EXP_ROOT}/exp1/cr_logs_done ${EXP_ROOT}/exp1/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp1

	touch ${@}

exp_1_outputs: /mnt/parsed/exp1/FCT_parsed
	@echo "Outputs done"

/mnt/parsed/exp2/FCT_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_FCT_pcap.py /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/helpers/get_partial_completion_offset.py ${EXP_ROOT}/exp2/cr_logs_done ${EXP_ROOT}/exp2/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp2

	touch ${@}

exp_2_outputs: /mnt/parsed/exp2/FCT_parsed
	@echo "Outputs done"

/mnt/parsed/exp3/loss_stats_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_loss_stats.py ${EXP_ROOT}/exp1/cubic_logs_done ${EXP_ROOT}/exp1/cr_logs_done ${EXP_ROOT}/exp1/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp3
	touch ${@}


/mnt/parsed/exp3/FCT_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_FCT_pcap_cross.py ${EXP_ROOT}/exp1/cubic_logs_done ${EXP_ROOT}/exp1/cr_logs_done ${EXP_ROOT}/exp1/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp3
	touch ${@}


exp_3_outputs: /mnt/parsed/exp3/loss_stats_parsed
	@echo "Outputs done"

/mnt/parsed/exp4/loss_stats_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_loss_stats.py ${EXP_ROOT}/exp1/cubic_logs_done ${EXP_ROOT}/exp1/cr_logs_done ${EXP_ROOT}/exp1/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp4
	touch ${@}

/mnt/parsed/exp4/FCT_parsed: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/parsers/parse_FCT_pcap_cross.py ${EXP_ROOT}/exp4/cubic_logs_done ${EXP_ROOT}/exp4/cr_logs_done ${EXP_ROOT}/exp4/high_IW_logs_done
	mkdir -p ${@D}
	python3 ${<} exp4
	touch ${@}

exp_4_outputs: /mnt/parsed/exp4/loss_stats_parsed
	@echo "Outputs done"


/mnt/plots/FCT_exp1.png /mnt/plots/FCT_exp1.pdf: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/plot_FCT.py /mnt/parsed/exp1/FCT_parsed
	python3 ${<} /mnt/parsed/exp1 ${@}

/mnt/plots/FCT_exp2.png /mnt/plots/FCT_exp2.pdf: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/plot_FCT.py /mnt/parsed/exp2/FCT_parsed
	python3 ${<} /mnt/parsed/exp2 ${@}

/mnt/plots/FCT_stats_cross_exp3.txt: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/FCT_stats_cross.py /mnt/parsed/exp3/FCT_parsed
	python3 ${<} /mnt/parsed/exp3 > ${@}

/mnt/plots/FCT_stats_cross_exp4.txt: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/FCT_stats_cross.py /mnt/parsed/exp4/FCT_parsed
	python3 ${<} /mnt/parsed/exp4 > ${@}


/mnt/plots/exp3_loss.txt: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/latex_table_generator.py exp_3_outputs
	python3 ${<} ${@} /mnt/parsed/exp3/loss_stats.json
	@echo "Done"

exp_3_table: /mnt/plots/exp3_loss.txt

/mnt/plots/exp4_loss.txt: /home/mihail/quicoptsat/emulation/quicopsat-stage2/scripts/processing/generators/latex_table_generator.py exp_4_outputs
	python3 ${<} ${@} /mnt/parsed/exp4/loss_stats.json
	@echo "Done"

exp_4_table: /mnt/plots/exp4_loss.txt


test:
	mkdir -p /mnt/logs/test/cr/10
	python3 experiment_driver.py server_cr.json /mnt/logs/test/cr/10 1 10
