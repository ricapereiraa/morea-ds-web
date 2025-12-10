import shutil
import tempfile
from pathlib import Path
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from .graphs import generateAllMotes24hRaw
from .models import (
	AuthTypes,
	Data,
	Device,
	DeviceTypes,
	Graph,
	GraphsTypes,
)


class GenerateAllMotes24hRawTests(TestCase):
	def setUp(self):
		self.temp_media = tempfile.mkdtemp(prefix="morea-media-")

	def tearDown(self):
		shutil.rmtree(self.temp_media, ignore_errors=True)

	def _create_device_with_samples(self, device_type, name, values):
		device = Device.objects.create(
			name=name,
			type=device_type,
			is_authorized=AuthTypes.Authorized,
		)

		base_time = timezone.now()
		for offset, value in enumerate(values):
			Data.objects.create(
				device=device,
				type=device_type,
				last_collection=value,
				total=value,
				collect_date=base_time - timedelta(hours=offset),
			)

		return device

	def test_generate_all_motes_creates_graph_files(self):
		with self.settings(MEDIA_ROOT=self.temp_media):
			self._create_device_with_samples(DeviceTypes.water, "Water-1", [10.0, 15.0])
			self._create_device_with_samples(DeviceTypes.energy, "Energy-1", [5.0])
			self._create_device_with_samples(DeviceTypes.gas, "Gas-1", [2.5, 3.5, 4.0])

			generateAllMotes24hRaw()

		expected_paths = {
			GraphsTypes.allWMoteDevices24hRaw: 'graphs/allWMoteDevices24hRaw.html',
			GraphsTypes.allEMoteDevices24hRaw: 'graphs/allEMoteDevices24hRaw.html',
			GraphsTypes.allGMoteDevices24hRaw: 'graphs/allGMoteDevices24hRaw.html',
		}

		for graph_type, relative_path in expected_paths.items():
			graph_entry = Graph.objects.get(type=graph_type)
			self.assertEqual(graph_entry.file_path, relative_path)
			self.assertTrue((Path(self.temp_media) / relative_path).is_file())

	def test_generate_all_motes_handles_missing_devices(self):
		with self.settings(MEDIA_ROOT=self.temp_media):
			generateAllMotes24hRaw()

		for graph_type in (
			GraphsTypes.allWMoteDevices24hRaw,
			GraphsTypes.allEMoteDevices24hRaw,
			GraphsTypes.allGMoteDevices24hRaw,
		):
			self.assertTrue(Graph.objects.filter(type=graph_type).exists())
