import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('compare',Path(__file__).resolve().parents[1]/'work/registar/tools/compare_classifiers.py')
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)
class ComparisonTests(unittest.TestCase):
    def test_agreement_is_not_accuracy(self):
        prediction={'category':'combat','purpose':'combat','classified':True}
        report=compare.compare({'a':{'x':prediction},'b':{'x':prediction}})
        self.assertEqual(report['agreements']['a:b']['category_agreement'],1)
        self.assertIsNone(report['methods']['a']['accuracy_on_classified'])
        report=compare.compare({'a':{'x':prediction,'y':{'category':'other','classified':False}}},
                               {'x':{'category':'other'},'y':{'category':'gear'}})
        self.assertEqual(report['methods']['a']['coverage'],.5)
        self.assertEqual(report['methods']['a']['accuracy_on_classified'],0)
        self.assertEqual(report['methods']['a']['correct_fraction_of_reference'],0)
    def test_multiple_selections_are_compared_as_sets(self):
        a={'category':'other','categories':['gear','appearance'],'classified':True}
        b={'category':'other','categories':['action','items'],'classified':True}
        report=compare.compare({'a':{'x':a},'b':{'x':b}}, {'x':{'categories':['appearance','gear']}})
        self.assertEqual(report['agreements']['a:b']['category_agreement'],0)
        self.assertEqual(report['methods']['a']['accuracy_on_classified'],1)
        self.assertEqual(report['methods']['a']['categories'],{'appearance':1,'gear':1})
if __name__=='__main__': unittest.main()
