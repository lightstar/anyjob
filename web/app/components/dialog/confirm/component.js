/**
 * Define 'confirmDialog' component used to ask user confirmation via modal dialog.
 * Usage:
 *     $uibModal.open({
           component: 'confirmDialog',
           resolve: {
               text: function() {
                   return '...';
               }
            }
       }).result.then(function () { ... }, function() { ... });
 *
 * Author:       LightStar
 * Created:      06.01.2019
 * Last update:  08.01.2019
 */

app.component('confirmDialog', {
    bindings: {
        resolve: '<',
        close: '&',
        dismiss: '&'
    },

    controller: ['focus', function (focus) {
        var $ctrl = this;

        /**
         * Initialize component.
         */
        $ctrl.$onInit = function () {
            $ctrl.id = guidGenerator();
            $ctrl.text = $ctrl.resolve.text || 'Are you sure?';
            focus('yes-' + $ctrl.id);
        };

        /**
         * Callback function called when user clicks 'Yes' button.
         */
        $ctrl.onYes = function () {
            $ctrl.close({$value: true});
        };

        /**
         * Callback function called when user clicks 'No' button.
         */
        $ctrl.onNo = function () {
            $ctrl.dismiss({$value: null});
        };
    }],

    templateUrl: 'app/components/dialog/confirm/template.html'
});
