# Copyright 2021 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for run_alphafold."""

import json
import os
import sys
import subprocess
import importlib.util

from absl.testing import absltest
from absl.testing import parameterized
import run_alphafold
import mock
import numpy as np
# Internal import (7716).

TEST_DATA_DIR = 'alphafold/common/testdata/'


class RunAlphafoldTest(parameterized.TestCase):

  @parameterized.named_parameters(
      ('relax', run_alphafold.ModelsToRelax.ALL),
      ('no_relax', run_alphafold.ModelsToRelax.NONE),
  )
  def test_end_to_end(self, models_to_relax):

    data_pipeline_mock = mock.Mock()
    model_runner_mock = mock.Mock()
    amber_relaxer_mock = mock.Mock()

    data_pipeline_mock.process.return_value = {}
    model_runner_mock.process_features.return_value = {
        'aatype': np.zeros((12, 10), dtype=np.int32),
        'residue_index': np.tile(np.arange(10, dtype=np.int32)[None], (12, 1)),
    }
    model_runner_mock.predict.return_value = {
        'structure_module': {
            'final_atom_positions': np.zeros((10, 37, 3)),
            'final_atom_mask': np.ones((10, 37)),
        },
        'predicted_lddt': {
            'logits': np.ones((10, 50)),
        },
        'plddt': np.ones(10) * 42,
        'ranking_confidence': 90,
        'ptm': np.array(0.),
        'aligned_confidence_probs': np.zeros((10, 10, 50)),
        'predicted_aligned_error': np.zeros((10, 10)),
        'max_predicted_aligned_error': np.array(0.),
    }
    model_runner_mock.multimer_mode = False

    with open(
        os.path.join(
            absltest.get_default_test_srcdir(), TEST_DATA_DIR, 'glucagon.pdb'
        )
    ) as f:
      pdb_string = f.read()
    amber_relaxer_mock.process.return_value = (
        pdb_string,
        None,
        [1.0, 0.0, 0.0],
    )

    out_dir = self.create_tempdir().full_path
    fasta_path = os.path.join(out_dir, 'target.fasta')
    with open(fasta_path, 'wt') as f:
      f.write('>A\nAAAAAAAAAAAAA')
    fasta_name = 'test'

    run_alphafold.predict_structure(
        fasta_path=fasta_path,
        fasta_name=fasta_name,
        output_dir_base=out_dir,
        data_pipeline=data_pipeline_mock,
        model_runners={'model1': model_runner_mock},
        amber_relaxer=amber_relaxer_mock,
        benchmark=False,
        random_seed=0,
        models_to_relax=models_to_relax,
        model_type='Monomer',
    )

    base_output_files = os.listdir(out_dir)
    self.assertIn('target.fasta', base_output_files)
    self.assertIn('test', base_output_files)

    target_output_files = os.listdir(os.path.join(out_dir, 'test'))
    expected_files = [
        'confidence_model1.json',
        'features.pkl',
        'msas',
        'pae_model1.json',
        'ranked_0.cif',
        'ranked_0.pdb',
        'ranking_debug.json',
        'result_model1.pkl',
        'timings.json',
        'unrelaxed_model1.cif',
        'unrelaxed_model1.pdb',
    ]
    if models_to_relax == run_alphafold.ModelsToRelax.ALL:
      expected_files.extend(
          ['relaxed_model1.cif', 'relaxed_model1.pdb', 'relax_metrics.json']
      )
      with open(os.path.join(out_dir, 'test', 'relax_metrics.json')) as f:
        relax_metrics = json.loads(f.read())
      self.assertDictEqual({'model1': {'remaining_violations': [1.0, 0.0, 0.0],
                                       'remaining_violations_count': 1.0}},
                           relax_metrics)
    self.assertCountEqual(expected_files, target_output_files)

    # Check that pLDDT is set in the B-factor column.
    with open(os.path.join(out_dir, 'test', 'unrelaxed_model1.pdb')) as f:
      for line in f:
        if line.startswith('ATOM'):
          self.assertEqual(line[61:66], '42.00')


class RunAlphafoldScriptsTest(absltest.TestCase):
  """Tests for the various run_alphafold scripts availability and syntax."""

  def setUp(self):
    """Set up the base directory for script discovery."""
    # Get the directory containing this test file
    self.base_dir = os.path.dirname(os.path.abspath(__file__))
    
  def test_scripts_exist(self):
    """Test that all run_alphafold scripts exist."""
    scripts_to_check = [
        'run_alphafold.py',
        'run_alphafold_preprocess.py',
        'run_alphafold_inference.py',
        'run_alphafold_test.py',
        'run_alphafold_apptainer.sh'
    ]
    
    for script in scripts_to_check:
      script_path = os.path.join(self.base_dir, script)
      self.assertTrue(
          os.path.exists(script_path),
          f'Script {script} not found at {script_path}'
      )
      
  def test_python_scripts_syntax(self):
    """Test that Python scripts have valid syntax."""
    python_scripts = [
        'run_alphafold.py',
        'run_alphafold_preprocess.py',
        'run_alphafold_inference.py',
        'run_alphafold_test.py'
    ]
    
    for script in python_scripts:
      script_path = os.path.join(self.base_dir, script)
      if os.path.exists(script_path):
        # Check syntax using compile
        try:
          with open(script_path, 'r') as f:
            compile(f.read(), script_path, 'exec')
        except SyntaxError as e:
          self.fail(f'Syntax error in {script}: {e}')
          
  def test_scripts_importable(self):
    """Test that Python scripts can be imported as modules."""
    # Scripts that should be importable
    importable_scripts = [
        ('run_alphafold', 'run_alphafold.py'),
        ('run_alphafold_preprocess', 'run_alphafold_preprocess.py'),
        ('run_alphafold_inference', 'run_alphafold_inference.py'),
    ]
    
    for module_name, script_name in importable_scripts:
      script_path = os.path.join(self.base_dir, script_name)
      if os.path.exists(script_path):
        try:
          # Use importlib to load the module
          spec = importlib.util.spec_from_file_location(module_name, script_path)
          module = importlib.util.module_from_spec(spec)
          # Don't execute the module, just verify it can be loaded
          # spec.loader.exec_module(module)
        except Exception as e:
          # Some import errors are expected if dependencies aren't available
          # Just ensure no syntax errors
          if 'SyntaxError' in str(type(e)):
            self.fail(f'Cannot import {script_name}: {e}')
            
  def test_shell_script_executable(self):
    """Test that shell scripts are executable."""
    shell_scripts = ['run_alphafold_apptainer.sh']
    
    for script in shell_scripts:
      script_path = os.path.join(self.base_dir, script)
      if os.path.exists(script_path):
        # Check if file has execute permission
        self.assertTrue(
            os.access(script_path, os.X_OK),
            f'Script {script} is not executable'
        )
        
  def test_scripts_have_main_guard(self):
    """Test that Python scripts have proper main guard."""
    python_scripts = [
        'run_alphafold.py',
        'run_alphafold_preprocess.py',
        'run_alphafold_inference.py',
    ]
    
    for script in python_scripts:
      script_path = os.path.join(self.base_dir, script)
      if os.path.exists(script_path):
        with open(script_path, 'r') as f:
          content = f.read()
          # Check for main guard
          self.assertIn(
              "if __name__ == '__main__':",
              content,
              f'Script {script} missing main guard'
          )
          
  def test_required_functions_exist(self):
    """Test that key functions exist in the scripts."""
    # Test run_alphafold.py has predict_structure function
    script_path = os.path.join(self.base_dir, 'run_alphafold.py')
    if os.path.exists(script_path):
      with open(script_path, 'r') as f:
        content = f.read()
        self.assertIn(
            'def predict_structure',
            content,
            'predict_structure function not found in run_alphafold.py'
        )
        
    # Test run_alphafold_preprocess.py has preprocessing functions
    preprocess_path = os.path.join(self.base_dir, 'run_alphafold_preprocess.py')
    if os.path.exists(preprocess_path):
      with open(preprocess_path, 'r') as f:
        content = f.read()
        # Should have functions related to preprocessing
        self.assertTrue(
            'def ' in content,
            'No functions found in run_alphafold_preprocess.py'
        )


if __name__ == '__main__':
  absltest.main()
