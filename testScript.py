import json, requests, time

test_pico_names = [f'script_test_{i}' for i in range(10)]

# Get all the current sensors
sensors = json.loads(requests.get("http://localhost:8080/sky/cloud/FxjKgaMMPr4CoLAW1NB4Wx/manage_sensors/sensors").text)
# **************************** Create 10 new sensors
for name in test_pico_names:
    assert name not in sensors, f"{name} existed before the tests script started."
    createUrl = 'http://localhost:8080/sky/event/FxjKgaMMPr4CoLAW1NB4Wx	/creatingSensors/sensor/new_sensor'
    result = requests.post(createUrl, data = {'name': name})

# This is hacky but oh well
time.sleep(3)

# # Get all the current sensors - sciprt_test_# sensors should exist now
with_new_sensors = json.loads(requests.get("http://localhost:8080/sky/cloud/FxjKgaMMPr4CoLAW1NB4Wx/manage_sensors/sensors").text)
# Send new temperature reading
for name in test_pico_names:
    eci = with_new_sensors[name]
    url1 = f'http://localhost:8080/sky/event/{eci}/aStringThing/wovyn/heartbeat'
    body = {"genericThing": {"data": {"temperature": [{"temperatureF": 1}]}}}
    heartbeat = requests.post(url1, json = body)

# More hacky
time.sleep(3)

# Get temps
temps = json.loads(requests.get("http://localhost:8080/sky/cloud/FxjKgaMMPr4CoLAW1NB4Wx/manage_sensors/temperatures").text)
# **************************** Make sure heartbeat worked
for name in test_pico_names:
    body = json.loads(temps[name])
    assert body[0]['temperature'] == 1

# Update profile
for name in test_pico_names:
    eci = with_new_sensors[name]
    url = f'http://localhost:8080/sky/event/{eci}/aStringThing/sensor/profile_updated'
    body = {"name": name, "location": f'location_{name}'}
    requests.post(url, json = body)

# **************************** Make sure profile update worked
for name in test_pico_names:
    eci = with_new_sensors[name]
    url = f'http://localhost:8080/sky/cloud/{eci}/sensor_profile/get_profile'
    result = requests.get(url)
    profile = json.loads(result.text)
    assert profile['name'] == name
    assert profile['location'] == f'location_{name}'

# Remove all the sensors
for name in test_pico_names:
    # **************************** Make sure all 10 new sensors were created
    assert name in with_new_sensors, f"Test pico {name} must not have been created "
    deleteUrl = 'http://localhost:8080/sky/event/FxjKgaMMPr4CoLAW1NB4Wx	/creatingSensors/sensor/unneeded'
    result = requests.post(deleteUrl, data = {'name': name})

# Hacky again
time.sleep(3)

# Get all the current sensors - sciprt_test_# sensors should be deleted
sensors_removed = json.loads(requests.get("http://localhost:8080/sky/cloud/FxjKgaMMPr4CoLAW1NB4Wx/manage_sensors/sensors").text)
# Make sure the picos were removed
for name in test_pico_names:
    assert name not in sensors_removed

print('All Tests Passed')
