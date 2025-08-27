scan:
	sudo agedu -s /data/
	sudo chown -R ${USER}:${USER} ./agedu.dat
	# Ensure no old agedu processes are running before restarting the service
	killall -q agedu || true

serve:
	@while true; do \
		agedu --auth none -f agedu.dat -w --address 0.0.0.0:5432; \
		echo "agedu crashed with exit code $$?.  Respawning.." >&2; \
		sleep 1; \
	done
